$(document).ready ->
  $('#newURLButton').click ->
    event.preventDefault()
    $.post '/add', $('#newURLForm').serialize()
      .done ->
        $('.newURLAlert').addClass('hide')
        $('#newURLSuccess').removeClass('hide')
        URLCell = document.createElement('td')
        URL = $('#url').val()
        $(URLCell).append(URL)
        typeCell = document.createElement('td')
        type = $('#type').val()
        $(typeCell).append(type)
        row = document.createElement('tr')
        $(row).append(URLCell, typeCell)
        $('#URLTable').append(row)
      .fail (error) ->
        $('.newURLAlert').addClass('hide')
        $("##{ error['responseText'] }").removeClass('hide')

  $('#runChecksButton').click ->
    event.preventDefault()
    $.get '/run', {}
      .done ->
        $('#checkRunAlert').removeClass('hide')