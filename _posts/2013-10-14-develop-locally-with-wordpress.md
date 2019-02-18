---
layout: post
title: Develop Locally with WordPress
description: Or how to stop working directly on your production site
keywords: WordPress, local, development, MAMP, mysql, symlink, plugin, theme
---

There seems to be a common complaint that working on WordPress plugins and themes locally is difficult to accomplish. If you only need to manage a handful of plugins or a couple themes, the tedium of setting up a dev environment isn't too complicated; you would probably just have a single install of WP on a MAMP server. As my 8th-grade english teacher would say: done, like a cupcake!

Things start to get real messy, though, when you manage 20+ client projects including custom themes, plus a slew of shared plugins between them. Throw in source control (this should go without question, but I hope you're using source control), and you have a nightmarish franken-MAMP that requires so much overhead to switch between themes and plugins it's just not worth the effort. Next thing you know, you're cowboy-coding on a live site in an alleyway with an ancient MacBook with broken `(`, `-` and `[` keys. Or so I've been told...

Today, I would like to cover how I handle WP development locally. It's not perfect, it's not ideal and I am totally open to suggestions on ways to improve it. However, it does solve the biggest headaches I have with working on WP locally.

### It's dangerous to go alone! Take this! ###

Depending on your environment, you will need slightly different tools. As I work mostly within OSX, I will be speaking from that perspective, but this process should be executable on any OS. Here's what you need:

* **A development server**: [MAMP][mamp] for Mac, [LAMP][lamp] for Linux, or [WAMP][wamp] for Windows

* **A command line interface (CLI)**, such as Terminal for Mac or PowerShell for Windows

No, really, that's it. If you are reading this, chances are you probably already had *AMP installed, and all OS's as far as I know come with some CLI that will do what we need to do.

### Setting up your file structure ###

The first goal of this workflow is to be as DRY as possible with respect to our project files. We want there to be only one version-controlled instance of each theme and plugin. This even includes 3rd-party plugins which you can update via the [WordPress' Plugin Repository][wpplugins].

Ok, here is our scenario: you want to work locally on www.example.com for ExampleCo. You've built (or are building) a custom theme with a custom plugin for a Foo Widget. The theme also uses a handful of custom plugins that you have built, like the (shameless plug) [Hansel &amp; Gretel][h&g] breadcrumb generator and other 3rd-party vendor plugins. The following file structure will keep your projects organized and clean:

![File structure for working locally on a WP project](http://res.cloudinary.com/rodaine/image/upload/v1381504849/WordPressLocalFileStructure_hursk2.png "This isn't the only way to accomplish this, but this structure works really well for me")

First, the `Clients` folder. Inside here will be folders containing each of the clients you have projects with. If you manage multiple projects for the same client, you will likely want them grouped together, which this structure permits. Under ExampleCo you will find the project folder for www.example.com. This folder is a source controlled repository containing two directories, one for themes (allowing you to have multiple themes for a particular project) and one for plugins that are custom to just that project. You will notice the example theme and foo-widget plugin contained within.

Next up is the `Environments` directory. Here you will keep the actual WordPress installs and where the magic of this workflow will take place. I keep this folder flat with the URL of the project's site (or a fake one for custom plugins, like hansel-gretel.rodaine.com). More on this directory later...

Our `Plugins` folder contains our custom WP plugins that are shared across projects. Each plugin directory in here is a repository linked to either the WordPress SVN or another SCM service.

And finally, the `Vendor` directory collects all our 3rd-party plugins or themes as repositories. This is essentially the same as the Plugins folder, but contains projects you do not actively maintain or contribute to. If it doesn't bother you, you could probably combine the two.

### Preparing your environment ###

Our first step will be getting WordPress up and running for our dev environment. In the www.example.com folder in `Environments`, we will [download the latest version of WordPress][wpdl].

Next, we need to point Apache to this directory as the document root for the server. While this might require messing around with the Apache configuration files to set up, MAMP makes it super easy:

1. Start up MAMP and click *Preferences*.

2. In the preferences modal, click Apache and the only setting available is to change to the document root.

3. Point it to the folder in `Environments` and click *OK*. The Apache and MySQL servers will restart automatically.

![View of the Document Root setting in MAMP](http://res.cloudinary.com/rodaine/image/upload/v1381512645/MAMPDocumentRoot_ddovzy.png "It might also be useful to set your ports to 8888 and 8889 for Apache and MySQL, respectively.")

When you have multiple environments configured, you will need to change the document root to switch between them. If you find this to be tedious, purchasing and setting up MAMP Pro (or a bit more manual work beyond the scope of this article) will allow you to run multiple local environments simultaneously by giving them different URLs (eg, example.dev, foobar.dev). It's your call, but I find that I can only do one thing at a time, and having to manually switch keeps me focused on the task at-hand.

Also, you might find it annoying that there are multiple identical installs of WordPress side-by-side. Trust me, I think it's gross, too. However, this will give you the opportunity to debug issues related to the WordPress version you are running. For instance, when WP updates, you will want to test that the update doesn't break any features on the live site before you go and hit that upgrade button. Likewise, it's a good habit to test your plugins on beta versions of WP to ensure there are no regressions resulting from those changes. It certainly beats the ire of everyone who has your plugin or theme installed overloading your support forum when you neglect to remove deprecated code.

Now we need to add a database on the MySQL server for this particular environment. When starting up MAMP, it will give you easy access to a phpMyAdmin instance for your MySQL server, or you can use a nice native tool like [Sequel Pro][sqlpro] to create the database. We'll name it `example_wordpress`.

With the servers configured and ready, we can now install WordPress. Access your environment on your localhost (at whichever port MAMP is configured to run at) and WP will walk you through the process of setting it up. If all is said and done, you should have WordPress running locally on your machine. Hooray!

### Linking to your plugins and themes ###

Alright, the moment we've been waiting for! How do we include our plugins and themes in the environment without having a configuration mess? The answer: *symoblic links*.

Symbolic links, or [symlinks][symlinks], are similar to Mac's aliases or Windows' shortcuts in that they a reference to a directory (or file) in a different location, but unlike either, they actually affect pathname resolution. *What does that even mean?!* Simply put, it means that WordPress (a'la PHP and Apache) will be able to find and use the files in these links as if they were actually included in the environment. [Wikipedia][symlinks] can elucidate symlinks further, if you are curious, but for the purposes of this discussion, believe me when I say they just work.

Ok, so how do we make them? It's fairly simple, but we will need to use the CLI. Lots of folks are uncomfortable in Terminal or Command Prompt. I don't blame them. There are GUI solutions to make symlinks for both [Windows][wingui] and [Mac][macgui], but I have not used them and I do not know how well they will work. That said, the CLI command to make the links is easy-peasy:

#### Mac or *nix Symbolic Links ####

    ln -s target_path link_path

<aside>Getting the paths into Terminal can be annoying, but a handy shortcut for quickly adding paths to your command is to drag and drop a directory or file from Finder into Terminal. Its path will automagically be added to the end of the current command!</aside>

The [`ln`][ln] command by itself will create a hard link which is *not* what we want. The `-s` flag tells it to make a symlink instead. The `target_path` is an absolute or relative path to the target folder you want to link to; it sometimes helps to think of it as the source. The `link_path` is where you want the link to exist; again, I like to think of it as the destination. So, to get our example theme into our environment we would execute the following in Terminal.

    ln -s ~/Clients/ExampleCo/www.example.com/themes/example ~/Environments/www.example.com/wp-content/themes/example

If you check Finder, you should see the alias arrow icon on the directory icon for the example theme inside the environment. Again, just to be clear, it's not an alias though, but the icon lets us know we did it correctly.

#### Windows Symbolic Links ####

    mklink /d link_path target_path

The [`mklink`][mklink] command is somewhat different. The `/d` flag makes sure that the symlink is a directory and not a file (which is the default). In this case, the link and target paths are reversed compared to the *nix version. Here is our previous example on Windows:

    mklink /d \Users\Rodaine\Environments\www.example.com\wp-content\themes\example \Users\Rodaine\Clients\ExampleCo\www.example.com\themes\example

With that completed, you can repeat this step for all plugins and themes you want available in your dev environment. Once all the symlinks are set up, you should be able to go to your localhost, login as the admin, activate your themes and plugins and begin developing locally! No more FTP to develop your themes and plugins! It's a good feeling...

### So, what's the catch? ###

Of course, there is a catch. Actually a couple. Unfortunately, there are no easy ways around these, but there are workarounds to make them less of a burden on your workflow.

#### Keeping the Database In-Sync ####

WordPress has **many** settings right out of the box. Don't believe me? After a clean install, there are already 99 entries in the options table (where the settings are stored). The vast majority of plugins that have options will also make use of this table, not to mention any custom tables they also add. Widgets, menus, nearly *everything* is maintained by the database (understandably), so how on earth do you keep the production and dev environment databases on the same page?

For plugin development, this is a non-issue. Your plugins should behave independent of everything else, regardless of where it is installed. Custom themes, on the other hand, are much more reliant on the site settings for certain features (like navigation menus). In these cases, having a copy of the database on your dev machine closely matching the live site is ideal.

You have a couple of options to tackle this issue. The first: manually copy the database from the live site to the dev site. This process is, in a word, unpleasant. You also need to take care in changing some of the values in the tables to refer to localhost as oppossed to the actual site domain. No one likes the first option.

The second, and more reasonable option, is to use a plugin like [WP Migrate DB Pro][wmdp]. You install the plugin on your production and dev sites and click a single button to sync the databases. It's as easy as that. Don't just take my word for it, though; [Chris Coyier loves it][coyier]. It costs a bit if you are managing more than 6 sites, but considering the time it saves, the expense is well justified.

#### Filepath-related issues ####

For me, this has been the biggest gotcha. Here's the deal: anywhere a plugin or theme makes reference to the filepath, in particular the [`__FILE__`][file] magic constant, there is a chance your code will break. From experience, calling [`plugin_dir_path(__FILE__)`][pdp] in a symlinked file works out fine, while [`plugin_dir_url(__FILE__)`][pdu] does not and will return an erroneous URL.

Getting around this drawback feels hackish; you have to hardcode certain path values. Luckily, these are all relative to your theme or plugin directories, but it still could be annoying if you were to change the file structure of your plugin. When defining path & url constants in a custom plugin, I do something like the following to avoid symlink issues:

    // check if developing locally
    define('SLEIGHT_LOCAL', $_SERVER['SERVER_NAME'] == 'localhost');

    // this will resolve correctly regardless of the environment
    define('SLEIGHT_PUBLIC_PATH', plugin_dir_path(__FILE__).'assets/');

    // this value is sensitive to symlinks
    define('SLEIGHT_PUBLIC_URL', SLEIGHT_LOCAL ? plugins_url().'/sleight/assets/' : plugin_dir_url(__FILE__).'assets/');

First we check if we're running locally in `SLEIGHT_LOCAL`. While `SLEIGHT_PUBLIC_PATH` is unaffected, the URL version is. If we are local, we use [`plugins_url()`][pu] instead to get the absolute URL for the plugins folder (usually just '/wp-content/plugins') and hardcode in the full path to the directory we want. Not too bad, right? If you wanted, you can drop the check altogether and rely on the `plugins_url()` method.

### Happy Coding! ###

Thanks for sticking in there! I've found this local workflow to be a great time-saver and overall keeps projects nice & tidy. Give it a try and let me know what you think. I am totally open to suggestions on how to make this even better.


[mamp]: http://www.mamp.info/
[lamp]: http://en.wikipedia.org/wiki/LAMP_(software_bundle)
[wamp]: http://www.wampserver.com/
[wpplugins]: http://wordpress.org/plugins/
[h&g]: https://github.com/Clark-Nikdel-Powell/Hansel-and-Gretel
[wpdl]: http://wordpress.org/download/
[sqlpro]: http://www.sequelpro.com/
[symlinks]: http://en.wikipedia.org/wiki/Symbolic_link
[wingui]: https://code.google.com/p/symlinker/
[macgui]: https://www.macupdate.com/app/mac/41493/symlinker
[wmdp]: https://deliciousbrains.com/wp-migrate-db-pro/
[coyier]: http://css-tricks.com/wp-migrate-db-pro/
[ln]: http://gigaom.com/2011/04/27/how-to-create-and-use-symlinks-on-a-mac/
[mklink]: http://technet.microsoft.com/en-us/library/cc753194(WS.10).aspx
[file]: http://php.net/manual/en/language.constants.predefined.php
[pdp]: http://codex.wordpress.org/plugin_dir_path
[pdu]: http://codex.wordpress.org/plugin_dir_url
[pu]: http://codex.wordpress.org/plugins_url
