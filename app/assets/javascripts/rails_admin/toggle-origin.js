(function ($) {
    $(document).on('click', ".toggle-origin", function(e){
        this.nextElementSibling.value++;
    });
})(jQuery);