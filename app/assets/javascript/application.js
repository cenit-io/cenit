window.App = (function () {
    const resizeListeners = [];

    const resize = document.body.onresize = function () {
        resizeListeners.forEach(listener => {
            try {
                listener();
            } catch (e) {
                console.error(e);
            }
        })
    };

    function addResizeListener(listener) {
        resizeListeners.push(listener);
    }

    return { resize, addResizeListener }
})();