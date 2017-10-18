(function ($) {

    $(document).on('click', ".toggle-origin", function (e) {
        this.nextElementSibling.value++;
    });

    $(document).on('click', ".toggle-boolean", function (e) {
        var that = this,
            $this = $(this),
            field = $this.data('field'),
            data = {},
            value = this.attributes['data-value'].value,
            xhr = new XMLHttpRequest();

        data[field] = value == 'true' ? false : true

        xhr.open("POST", $this.data('url'), true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onload = function () {
            if (xhr.status === 200) {
                var response = JSON.parse(xhr.responseText);
                $this.attr('data-value', response[field]);
            } else {
                $this.attr('data-value', value);
            }
            setupToggleBoolean(that);
        };
        xhr.onerror = function() { setupToggleBoolean(that); };
        this.previousElementSibling.innerHTML = '<i class="fa fa-spinner fa-spin fa-fw"></i>';
        this.innerHTML = '<i class="fa fa-toggle-' + (data[field] ? 'on' : 'off') + '"></i>';
        xhr.send(JSON.stringify(data));
    });
})(jQuery);