---
layout: post
title: RSA Keys and SSH Clients in Go (golang)
description: Or how one falls down the crypto-rabbit hole
---

I've been working on a side project called [Runner](https://github.com/rodaine/runner), which — as the name implies — involves _running_ arbitrary commands. These tasks can run in sequence, in parallel, in lock-step. They can be rolled back on error or dry-ran to simulate expected behavior without taking real action.

While the framework is very abstract, I have begun creating some concrete tasks (e.g., [writing files or rendering templates](https://godoc.org/github.com/rodaine/runner/files)). One of these (or suite thereof) involves executing any command on a remote server over SSH. Parallelized, this could be used to perform actions against a whole cluster simulataneously, all from the comfort of your local shell.

In order to do so, the SSH task must connect to the remote host, use one of a myriad of authentication methods to login, and either open a shell or execute a command. Simple enough? _Eh..._

### Our Contrived Example

Suppose, you want a tool that can get the disk usage of a remote host. If you were on it (and it was Ubuntu), you could do something like `df -h` to get a human-readable output of all mounted file systems and their usage information. So, we're going to have the tool SSH onto the box and execute the command for us.

<aside>Obviously, if your tool's only purpose was to pull disk usage from a single host, perhaps you shouldn't reinvent the wheel and instead opt for just <code>ssh host df -h</code>. Humor this poor unimaginative developer, if you would be so kind.</aside>

The tool will automatically use the SSH key stored in `$HOME/.ssh/id_rsa` or, if available, a configured and running SSH Agent. The command will be executed and the output returned to the user. Pretty straightforward!

To our benefit, the Go maintainers manage a bunch of packages in addition to the standard library; of particular interest here, the supplementary [crypto/ssh](https://godoc.org/golang.org/x/crypto/ssh) package contains the features necessary for connecting to a remote host. We will use these to construct our tool.

### Creating the SSH Client Connection

First, we construct an `ssh.Client` which opens a connection with the remote server and authenticates against it. When connecting, an `ssh.ClientConfig` struct is provided that specifies the username and authentication methods that should be attempted to gain access to the host. For now, we will use a password, as it's the simplest to configure:

{% include widgets/gist.html id="4082fc73d36cd90da029" file="client.go" %}

Notice that `ssh.ClientConfig.Auth` is a slice of `ssh.AuthMethod`. The client will attempt to use each method provided to authenticate in order, erroring out if none work or no methods are provided. Out of the box, the crypto/ssh package provides methods for passwords (as shown above), keyboard interactive challenges, key pairs, and ssh-agents. We will look into those last two in a bit.

Also, don't forget to defer `client.Close()` to release the underlying connection!

### Obtaining a Session

Clients do not run commands directly; instead, they are delegated to an `ssh.Session`. Under the hood, a session wraps an [SSH channel](http://net-ssh.github.io/ssh/v1/chapter-3.html) within the client's connection, maintaining the execution state of a single command.

{% include widgets/gist.html id="4082fc73d36cd90da029" file="session.go" %}

It is important to note that **sessions only execute one command**. However, multiple sessions can be created and run from the same client. In fact, these sessions can be executed in parallel.

As with client, don't forget to defer `sess.Close()`!

### Executing a Command

As mentioned before, sessions execute a single command, initiated with one (and only one!) of the following methods: `Run`, `Start`, `Output`, `CombinedOutput`, or `Shell`. Sessions also expose properties to manually configure stdin, stdout, and stderr for the command with any valid `io.Reader`/`io.Writer`. There are a few helper `Pipe*` methods to easily attach to these streams.

<aside>Sessions can also be used to login to a shell on the remote server, requesting psuedo-terminals and subsystems, as well as other more advanced interactions.</aside>

`Run` executes the command as provided, returning an error if it can't use to the connected i/o streams or if it exists with a non-zero code. `Start` is the same except that it is non-blocking. `Wait` should be subsequently called on the session to verify when the started command has completed. This is useful for a long-running command that doesn't need to be acted upon serially.

If setting up `io.Writer`s for stdout and stderr is overkill for your particular use case, `Output` and `CombinedOutput` will automatically capture the data returned by the command in a `[]byte`. While `Output` only captures stdout, `CombinedOutput` also includes stderr. For our disk usage example, we are going to use `Output`.

{% include widgets/gist.html id="4082fc73d36cd90da029" file="command.go" %}

Putting all of this together, we can now run our tool to see if everything's working as expected. If all goes according to plan, you should see the results of the `df -h` command:

{% include widgets/gist.html id="4082fc73d36cd90da029" file="execution.txt" %}

### Other Authentication Methods

If we intended to share our tool with others, our current implementation presents a minor problem: we've hardcoded the username and password (not to mention the host itself!). Also, if you've used SSH before, you'd probably agree entering a password with SSH is a <abbr title="pain in the ass">PITA</abbr>, and remote servers typically require SSH keys anyways. So let's use our keys instead!

#### RSA SSH Key

It is fairly standard today that if you have an SSH key, it's an RSA private key stored at `$HOME/.ssh/id_rsa` as a PEM-encoded block (that's an awful lot of acronyms... hold tight, 'cause it's only going to get worse).

So how do we get from that file to an `ssh.AuthMethod`? First, we need to get an `ssh.Signer` from our key, then we pass the signer to `ssh.PublicKeys()` to get our `AuthMethod`. It's pretty straightforward:

<aside>To get the user of your tool, Go lovingly provides you with <code>user.Current()</code>.</aside>

{% include widgets/gist.html id="4082fc73d36cd90da029" file="keyauth.0.go" %}

Kinda verbose with all the error handling, but still reasonable. For most folks, that's it! But some of you might end up with this obtuse error:

    asn1: structure error: tags don't match (16 vs {class:2 tag:6 length:102 isCompound:true}) {optional:false explicit:false application:false defaultValue:<nil> tag:<nil> stringType:0 timeType:0  set:false omitEmpty:false} pkcs1PrivateKey @2

Assuming your key isn't actually malformed, this error message is probably cropping up because your key is encrypted. You can check this easily by looking for `Proc-Type: 4,ENCRYPTED` immediately after the header in the file. If you're like me, you forgot that you password-protected your key when you created it. We'll need to make some changes to our `keyAuth` method to unlock our key.

#### Decrypting SSH Keys

To get at the metadata of our key file, we'll need to use two other packages: `encoding/pem` and `golang.org/x/crypto/x509`. The PEM package will allow us to gain access to the data of our key file in a `pem.Block` struct; the x509 package (referring to the X.509 standard for certificates) will decrypt the key with a provided password and convert it to an RSA private key signer:

{% include widgets/gist.html id="4082fc73d36cd90da029" file="keyauth.1.go" %}

With this, any key generated using the typical `ssh-keygen` tool should work as expected. You will have to figure out how to ask the user for the key's password, though. Still, some users will see a very similar error to the one above, generated by `x509.ParsePKCS1PrivateKey(b)`:

    asn1: structure error: tags don't match (2 vs {class:0 tag:16 length:13 isCompound:true}) {optional:false explicit:false application:false defaultValue:<nil> tag:<nil> stringType:0 timeType:0 set:false omitEmpty:false}  @5

While your typical SSH key follows the PKCS #1 standard, the encryption on these keys are easy to crack via brute-force (if they're even encrypted at all).

https://github.com/golang/go/issues/8860
https://github.com/youmark/pkcs8
