import onReady from './ready';
import loader from './script-loader';

onReady(() => {
	if (document.querySelector('.codepen')) {
		loader('https://cpwebassets.codepen.io/assets/embed/ei.js');
	}
})

