
(function () {
    const form = document.getElementById('openid_form');
    const buttons = Array.from(
        document.getElementById('openid_social').children
    ).map(div => div.children[0]);

    buttons.forEach(button => button.addEventListener('click', disableButtons));

    function disableButtons(e) {
        buttons.forEach(
            button => button.setAttribute('disabled', 'true')
        );
        document.getElementById('openid_with_parameter').value = e.target.value;
        form.submit();
    }
})();
