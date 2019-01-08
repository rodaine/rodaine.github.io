import loader from './script-loader';

function load(script: string) { loader(`https://go.disqus.com/${script}`); }

if (document.querySelector('[data-disqus-identifier]')) {
	load('count.js');
}

const thread = document.getElementById('disqus_placeholder');
if (thread) {
	thread.onclick = (e) => {
		e.preventDefault();
		thread.remove();
		load('embed.js');
	};
}
