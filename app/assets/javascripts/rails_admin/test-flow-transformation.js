(function () {

    $(document).on('click', "#test-transformation", function (e) {

        var flow_name = $("#setup_flow_name") ? $("#setup_flow_name").val() : '';

        var url = $(this).data('link');

        var dialog = $('<div id="modal" class="modal fade">\
            <div class="modal-header">\
              <a href="#" class="close" data-dismiss="modal">&times;</a>\
              <h3 class="modal-header-title">' + flow_name + 'Test transform</h3>\
            </div>\
            <div class="modal-body">\
              ...\
            </div>\
            <div class="modal-footer">\
              <div class="btn btn-primary" id="run_again">\
                <i class=\"icon-repeat\"></i>\
                Run again\
              </a>\
              <!-- a href="#" class="btn cancel-action">Close</a-->\
            </div>\
          </div>')
            .modal({
                keyboard: true,
                backdrop: true,
                show: true
            })
            .on('hidden', function () {
                dialog.remove();
                dialog = null;
            });

//        dialog.find('.cancel-action').unbind().click(function(){
//            dialog.modal('hide');
//        });

        dialog.find('#run_again').unbind().click(function () {

            setTimeout(function () {
                $.ajax({
                    url: url,
                    data: data + ($('#sample_data') ? 'sample_data=' + $('#sample_data').val() : ''),
                    beforeSend: function (xhr) {
                        xhr.setRequestHeader("Accept", "text/javascript");
                    },
                    success: function (data, status, xhr) {
                        dialog.find('.modal-body').html(data);
                    },
                    error: function (xhr, status, error) {
                        dialog.find('.modal-body').html(xhr.responseText);
                    },
                    dataType: 'text'
                });
            }, 200);
        });

        var data = $('#setup_flow_transformation') ? 'transformation=' + $('#setup_flow_transformation').val() + '&' : '';

        setTimeout(function () {
            $.ajax({
                url: url,
                data: data + ($('#setup_flow_data_type_id') ? 'data_type_id=' + $('#setup_flow_data_type_id').val() : ''),
                beforeSend: function (xhr) {
                    xhr.setRequestHeader("Accept", "text/javascript");
                },
                success: function (data, status, xhr) {
                    dialog.find('.modal-body').html(data);
                },
                error: function (xhr, status, error) {
                    dialog.find('.modal-body').html(xhr.responseText);
                },
                dataType: 'text'
            });
        }, 200);
    });

}).call(this);
