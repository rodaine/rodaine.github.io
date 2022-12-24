import onReady from './ready';

onReady(() => {
    document.querySelectorAll('h3, h4, h5, h6')
        .forEach((header) => {
            if (header.id === "") return;

            const link = document.createElement('a');
            link.href = `#${header.id}`;
            link.innerHTML = header.innerHTML;
            link.className = 'hlink';

            header.replaceChildren(link);
        });
});