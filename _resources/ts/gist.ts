import loader from './script-loader';

interface Gist {
	stylesheet: string;
	div: string;
}

interface GistWindow {
	[key: string]: (gist: Gist) => void;
}

class GistElement {
	private static counter = 0;
	private static readonly loadedGists: { [key: string]: Gist } = {};
	private static readonly loadedCSS: { [key: string]: undefined } = {};

	private readonly el: Element;
	private readonly id: string;
	private readonly user: string;
	private readonly file: string;
	private readonly callback: string;

	constructor(el: Element) {
		this.el = el;
		this.id = el.getAttribute('data-id');
		this.user = el.getAttribute('data-user');
		this.file = el.getAttribute('data-file');

		this.callback = `gist${GistElement.counter}`;
		GistElement.counter += 1;
	}

	public load() {
		let src = `https://gist.github.com/${this.user}/${this.id}.json`;
		if (this.file) {
			src += `?file=${this.file}`;
		}
		this.getJSON(src);
	}

	private getJSON(url: string) {
		if (GistElement.loadedGists[url]) {
			this.success(GistElement.loadedGists[url]);
			return;
		}

		const s = loader(url, false);

		((window as unknown) as GistWindow)[this.callback] = (data: Gist) => {
			GistElement.loadedGists[url] = data;
			this.success(data);
			document.body.removeChild(s);
		};

		const prefix = url.indexOf('?') > 0 ? '&' : '?';
		s.src = `${url}${prefix}callback=${this.callback}`;
		document.body.appendChild(s);
	}

	private success(g: Gist) {
		this.injectDiv(g.div);
		this.injectCSS(g.stylesheet);
	}

	private injectDiv(div: string) {
		this.el.innerHTML = div; // tslint:disable-line
	}

	private injectCSS(url: string) {
		if (GistElement.loadedCSS[url]) {
			return;
		}
		GistElement.loadedCSS[url] = undefined;

		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = url;
		document.head.appendChild(link);
	}
}

const els: [Element] = [].slice.call(document.getElementsByClassName('gist-wrapper'));
els.map(el => new GistElement(el))
	.map(el => el.load());
