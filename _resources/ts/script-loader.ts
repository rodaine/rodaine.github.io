export default function(url: string, autoAppend = true): HTMLScriptElement {
	const s = document.createElement('script');
	s.async = true;
	s.src = url;
	if (autoAppend) {
		document.body.appendChild(s);
	}
	return s;
}
