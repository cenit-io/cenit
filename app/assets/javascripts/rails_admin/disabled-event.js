(function ($) {
    $.propHooks.disabled = {
        set: function (el, value) {
            if (el.disabled !== value) {
                el.disabled = value;
                $(el).trigger(value ? 'disabled' : 'enabled');
            }
        }
    };
})(jQuery);
