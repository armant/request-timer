URL_COMPONENTS = ['url', 'type', 'headers', 'data']

makeFormId = (urlComponent, prependSymbol) ->
  prefix = if prependSymbol then '#' else ''
  return prefix + urlComponent

makeTableClass = (urlComponent, prependSymbol) ->
  prefix = if prependSymbol then '.' else ''
  return prefix + urlComponent + 'TableCell'

$(document).ready ->
  $('#type').change ->
    type = $(this).val()
    if type is 'GET'
      $('#dataWrapper').addClass 'hide'
    else if type is 'POST'
      $('#dataWrapper').removeClass 'hide'

  $('#newURLButton').click ->
    event.preventDefault()
    $('.urlAlert').addClass 'hide'
    url = $('#url').val()
    if not isUrlValid url
      $('#newURLErrorURL').removeClass 'hide'
      return
    type = $('#type').val()
    headers = $('#headers').val()
    data = if type is 'GET' then '' else $('#data').val()
    if headers
      try
        $.parseJSON headers
      catch jsonError
        $('#newURLErrorHeaders').removeClass 'hide'
        return
    data = if type is 'GET' then '' else $('#data').val()
    if data
      try
        $.parseJSON data
      catch jsonError
        $('#newURLErrorData').removeClass 'hide'
        return

    $.post '/url', $('#newURLForm').serialize()
      .done (newUrlId) ->
        if $('#rowToDelete').length
          $('#rowToDelete').remove()
          $('#updateURLSuccess').removeClass 'hide'
        else
          $('#newURLSuccess').removeClass 'hide'
        # Attach the new/updated URL to the top of the table
        tableCells = []
        for urlComponent in URL_COMPONENTS
          tableCell = document.createElement 'td'
          $(tableCell).addClass makeTableClass urlComponent
          $(tableCell).append $(makeFormId urlComponent, true).val()
          tableCells.push tableCell
        updateButton = document.createElement 'button'
        $(updateButton).attr
          'type': 'button'
          'class': 'btn btn-default updateUrl'
        $(updateButton).html 'Update'
        deleteButton = document.createElement 'button'
        $(deleteButton).attr
          'type': 'button'
          'class': 'btn btn-default deleteUrl'
        $(deleteButton).html 'Delete'
        buttonGrouper = document.createElement 'div'
        $(buttonGrouper).attr
          'class': 'btn-group'
          'role': 'group'
        $(buttonGrouper).append updateButton, deleteButton
        actionCell = document.createElement 'td'
        $(actionCell).append buttonGrouper
        row = document.createElement 'tr'
        $(row).attr
          'data-url-id': newUrlId
        $(row).append tableCells, actionCell
        $('#urlTableBody').prepend row
      .fail (requestError) ->
        $("##{ requestError['responseText'] }").removeClass 'hide'

  $('body').delegate '.updateUrl', 'click', ->
    $('.urlAlert').addClass 'hide'
    rowDom = $(this).closest 'tr'
    rowDom.attr 'id', 'rowToDelete'
    for urlComponent in URL_COMPONENTS
      formField = $ makeFormId urlComponent, true
      cellText = $(rowDom.find(makeTableClass urlComponent, true)[0]).text()
      formField.val cellText
    _id = rowDom.data 'url-id'
    $(makeFormId '_id', true).val(_id)
    type = $(rowDom.find('.typeTableCell')[0]).text()
    if type is 'GET'
      $('#dataWrapper').addClass 'hide'
    else if type is 'POST'
      $('#dataWrapper').removeClass 'hide'
    window.scrollTo 0, $('#newURLForm').offset()

  $('body').delegate '.deleteUrl', 'click', ->
    $('.urlAlert').addClass 'hide'
    rowDom = $(this).closest 'tr'
    _id = rowDom.data 'url-id'
    rowDom = $(this).closest 'tr'
    $.ajax
      url: '/url'
      type: 'DELETE'
      data: {_id: _id}
    .done ->
      rowDom.remove()
    .fail ->
      $('#deleteUrlError').removeClass 'hide'

isUrlValid = (url) ->
  /^(https?|s?ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test url