$(document).ready ->
  $('#type').change ->
    if $(this).val() is 'GET'
      $('#typeWrapper').addClass 'hide'
    else if $(this).val() is 'POST'
      $('#typeWrapper').removeClass 'hide'

  $('#newURLButton').click ->
    event.preventDefault()
    $('.newURLAlert').addClass 'hide'
    URL = $('#url').val()
    if not isURLValid URL
      $('#newURLErrorURL').removeClass 'hide'
      return
    data = $('#data').val()
    if data
      try
        $.parseJSON(data);
      catch jsonError
        $('#newURLErrorData').removeClass 'hide'
        return

    console.log $('#newURLForm').serialize()
    $.post '/add', $('#newURLForm').serialize()
      .done ->
        $('#newURLSuccess').removeClass 'hide'
        # Attach the new URL to the end of the table
        URLCell = document.createElement 'td'
        $(URLCell).append URL
        typeCell = document.createElement 'td'
        type = $('#type').val()
        $(typeCell).append type
        dataCell = document.createElement 'td'
        data = $('#data').val()
        $(dataCell).append data
        row = document.createElement 'tr'
        durationsCell = document.createElement 'td'
        averageCell = document.createElement 'td'
        $(row).append URLCell, typeCell, dataCell, durationsCell, averageCell
        $('#URLTable').append row
      .fail (requestError) ->
        $("##{ requestError['responseText'] }").removeClass 'hide'

  $('#runChecksButton').click ->
    event.preventDefault()
    $.get '/run', {}
      .done ->
        $('#checkRunAlert').removeClass 'hide'

isURLValid = (url) ->
  /^(https?|s?ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test url