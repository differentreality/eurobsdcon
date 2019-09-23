function remove_field($this) {
  // Deselect option
  var row_id = $this.parent().parent().attr('id');

  $("select#invoice_tickets option").each(function () {
    if ($(this).data('index') == row_id ){
      $(this).prop('selected', false);
    }
  });

  // Remove invoice item row
  $this.parent().parent().remove();
  payable_change();
}

// Change function content
// Instead of payable = total_amount + vat
// We keep payable as the total amount paid, and total_amount gets calculated accordingly
function calculatePayable() {
  var total_amount = (parseFloat($("#invoice_payable").val()) - parseFloat($("#invoice_vat").val()) ).toFixed(2);


  $("#invoice_total_amount").val(total_amount);
}

function payable_change(total_amount, vat) {
  if (!total_amount > 0) {
    var total_amount = parseFloat(0);
    var vat = parseFloat(0);
    var vat_nok = parseFloat(0);

    $('#description .row').each( function() {
      price = parseFloat($(this).find('#invoice_description__price').val() || 0).toFixed(2);
      quantity = parseFloat($(this).find('#invoice_description__quantity').val()) || 0;
      item_vat_percent = parseFloat($(this).find('#invoice_description__vat_percent').val()) || 0;

      // Math formula to calculate VAT value from gross price:
      // price * vat% / (vat% + 100)    <--- where price = price of 1 ticket * quantity bought
      item_vat = (parseFloat(price) * parseFloat(quantity) * parseFloat(item_vat_percent) / (parseFloat(item_vat_percent) + 100.0) ).toFixed(2) || 0;
      $(this).find('#invoice_description__vat').val(item_vat);

      total_amount = (parseFloat(total_amount) + parseFloat(price) * parseFloat(quantity)).toFixed(2);
      vat = (parseFloat(vat) + parseFloat(item_vat));

      var euro_nok_rate = $('#invoice_exchange_rate').val();
      item_vat_NOK = item_vat * euro_nok_rate;
      $(this).find('#item_vat_nok').text(item_vat_NOK.toFixed(2));
      vat_nok = (parseFloat(vat_nok) + parseFloat(item_vat_NOK)) || 0;
    });
  }

  $("#invoice_payable").val(total_amount);
  $("#invoice_vat").val(vat);
  $("#vat_nok").text(vat_nok.toFixed(2));

  calculatePayable()
}

$(function () {
  jQuery('option').mousedown(function(e) {
    e.preventDefault();
    jQuery(this).toggleClass('selected');

    jQuery(this).prop('selected', !jQuery(this).prop('selected'));
    return false;
  });

  $("[id^='tickets_collection_option']").click(function () {
    var row_id = $(this).data('index');
    var next_index = 0;
    if($(this).is(':selected')){
      $('#description .row').each( function(index, value) {
        if ( value.id > row_id ) {
          next_index = value.id;
          return false;
        }
      });

      if ( next_index == 0 ) {
        $('#description').append('<div class=row id=' + row_id + '>');
      }else{
        $('.row#' + next_index).before('<div class=row id=' + row_id + '>');
      }

      $('.row#' + row_id).append('<div class=col-md-3><input type="text" name="invoice[description][][description]" id="invoice_description__description" value="' + $(this).data('ticket-name') + '" autofocus="autofocus" class="form-control"></div> <div class=col-md-1><input type="number" name="invoice[description][][quantity]" id="invoice_description__quantity" value="' + parseFloat($(this).data('quantity')) + '" min="1" class="form-control" onchange="payable_change()"></div> <div class=col-md-2 style="padding: 0 0 0 0"> <input type="number" name="invoice[description][][price]" id="invoice_description__price" value=' + parseFloat($(this).data('price')).toFixed(1) + ' min="0" class="form-control" onchange="payable_change(0, 0)"> </div> <div class=col-md-2> <input type="text" name="invoice[description][][vat_percent]" id="invoice_description__vat_percent" value="' + parseFloat($(this).data('vat-percent')).toFixed(1) +'" autofocus="autofocus" class="form-control"> </div> <div class=col-md-2> <input type="text" name="invoice[description][][vat]" id="invoice_description__vat" value="" autofocus="autofocus" class="form-control"> </div> <div class=col-md-1 id=item_vat_nok>' +  + '</div> <div class=col-md-1> <a onclick="remove_field($(this))" title="Remove field" href="javascript: void(0)"><i class="fa fa-times btn btn-danger"></i></a></div><input type="hidden" name="invoice[description][][ticket_id]" id="invoice_description__ticket_id" value=' + parseFloat($(this).data('ticket_id')) + '>');
    }
    else {
      $('.row#' + row_id).remove();
    }
    payable_change(0);
  });

  $("#invoice_exchange_rate").change(function () {
    var vat_nok = parseFloat(0);
    var euro_nok_rate = $('#invoice_exchange_rate').val();
    // item NOK value
    $('#description .row').each( function() {
      item_vat_NOK = item_vat * euro_nok_rate;
      $(this).find('#item_vat_nok').text(item_vat_NOK.toFixed(2));
      vat_nok = (parseFloat(vat_nok) + parseFloat(item_vat_NOK));
    });

    // total VAT NOK value (hint)
    $("#vat_nok").text(vat_nok.toFixed(2));
  });

  // $("#invoice_total_amount").change(function () {
  //   $("#invoice_vat").val(($("#invoice_total_amount").val() * parseFloat($("#invoice_vat_percent").val()) / 100).toFixed(2));
  //   calculatePayable();
  // });

  // $("#invoice_payable").change(function () {
  //   payable_change($(this).val());
  // });
});
