$(document).ready ->
  $('#type').change ->
    if $(this).val() is 'GET'
      $('#dataWrapper').addClass 'hide'
    else if $(this).val() is 'POST'
      $('#dataWrapper').removeClass 'hide'

  $('#newURLButton').click ->
    event.preventDefault()
    $('.urlAlert').addClass 'hide'
    url = $('#url').val()
    if not isUrlValid url
      $('#newURLErrorURL').removeClass 'hide'
      return
    data = $('#data').val()
    if data
      try
        $.parseJSON(data);
      catch jsonError
        $('#newURLErrorData').removeClass 'hide'
        return

    $.post '/add-url', $('#newURLForm').serialize()
      .done (newUrlId) ->
        $('#newURLSuccess').removeClass 'hide'
        # Attach the new URL to the end of the table
        urlCell = document.createElement 'td'
        $(urlCell).append url
        typeCell = document.createElement 'td'
        type = $('#type').val()
        $(typeCell).append type
        dataCell = document.createElement 'td'
        data = $('#data').val()
        $(dataCell).append data
        actionCell = document.createElement 'td'
        updateButton = document.createElement 'button'
        $(updateButton).attr
          'type': 'button'
          'data-url-id': newUrlId
          'class': 'btn btn-default updateUrl'
        $(updateButton).html 'Update'
        deleteButton = document.createElement 'button'
        $(deleteButton).attr
          'type': 'button'
          'data-url-id': newUrlId
          'class': 'btn btn-default deleteUrl'
        $(deleteButton).html 'Delete'
        buttonGrouper = document.createElement 'div'
        $(buttonGrouper).attr
          'class': 'btn-group'
          'role': 'group'
        $(buttonGrouper).append updateButton, deleteButton
        $(actionCell).append buttonGrouper
        row = document.createElement 'tr'
        $(row).append urlCell, typeCell, dataCell, actionCell
        $('#urlTableBody').prepend row
      .fail (requestError) ->
        $("##{ requestError['responseText'] }").removeClass 'hide'

  $('body').delegate '.deleteUrl', 'click', ->
    $('.urlAlert').addClass 'hide'
    _id = $(this).data('url-id')
    rowDom = $(this).closest('tr')
    $.post '/delete-url', {_id: _id}
      .done ->
        rowDom.remove()
      .fail ->
        $('#deleteUrlError').removeClass 'hide'

  $('.updateUrl').click ->
    console.log $(this).data('url-id')

isUrlValid = (url) ->
  /^(https?|s?ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test url