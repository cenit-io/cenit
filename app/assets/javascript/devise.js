(function () {
    Array.from(
        document.getElementsByClassName('responsive-box')
    ).forEach(
        rbox => Array.from(rbox.getElementsByClassName('devise box')).forEach(
            dbox => window.App.addResizeListener(() => {
                const rect = dbox.getBoundingClientRect();
                const vh = Math.max(
                    document.documentElement.clientHeight || 0, window.innerHeight || 0
                );
                if (rect.height > vh) {
                    rbox.classList.remove('centered');
                } else {
                    rbox.classList.add('centered');
                }
            })
        )
    )
})();