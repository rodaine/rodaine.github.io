import loader from './script-loader';

const disqusURL = 'https://rodaine.disqus.com/';

if (document.querySelector('[data-disqus-identifier]')) {
	const s = loader(`${disqusURL}count.js`, false);
	s.id = 'dsq-count-scr';
	document.body.appendChild(s);
}

const thread = document.getElementById('disqus_placeholder');
if (thread) {
	thread.onclick = (e) => {
		e.preventDefault();
		thread.remove();

		const s = loader(`${disqusURL}embed.js`, false);
		s.setAttribute('data-timestamp', (new Date()).toString());
		document.body.appendChild(s);
	};
}
