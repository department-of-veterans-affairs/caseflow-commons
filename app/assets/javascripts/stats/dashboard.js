window.Dashboard = (function(d3, moment) {
  // private
  var data, interval, index, maxIndex, dateStrings, charts, values, rates, times, dates, tables, x, y, bars

  function init(opts) {
    data = opts.data
    interval = opts.interval

    index = 0
    maxIndex = data.length - 1
    dateStrings = data.map(function (d, i) {
      var date = moment.unix(d.key).tz('America/New_York')
      var str = ''
      switch (interval) {
      case 'hourly': str += date.format('HH:mm') + '–' + date.add(59, 'm').format('HH:mm z'); break
      case 'daily': str += date.format('MMMM D'); break
      case 'weekly': str += 'the week of ' + date.format('MMMM D'); break
      case 'monthly': str += date.format(i < 12 ? 'MMMM' : 'MMMM YYYY'); break
      default: str += date.format('X')
      }

      if (i === 0) { str += ' (so far)'}

      return str
    })

    charts = d3.selectAll('.data-chart')
      .call(setDataByKey)
      .append('svg')
    values = d3.selectAll('.data-value')
      .call(setDataByKey)
    rates = d3.selectAll('.data-rate')
      .call(setDataByKey)
    times = d3.selectAll('.data-time')
      .call(setDataByKey)
    tables = d3.select('.data-table')
      .call(setDataByKey)
    dates = d3.selectAll('.data-date')

    x = d3.scaleBand()
      .domain(d3.range(0, data.length))
      .paddingInner(0.1)

    y = d3.local()
    charts.property(y, function (d) {
      var max

      switch (d.key) {
      default: max = d3.max(d.values)
      }

      max = max > 1 ? max : 1

      return d3.scaleLinear()
        .domain([0, max])
    })

    charts.append('g').append('title').text('Historical Data')

    bars = charts.selectAll('.bar')
      .data(function (d) { return d.values })
      .enter().append('rect')
      .attr('class', 'bar')
      .attr('title', function (d, i) { return dateStrings[i] + ': ' + d })

    resize()

    d3.select(window)
      .on('resize', resize)
      .on('keydown', function () {
        switch (d3.event.keyCode || d3.event.detail.keyCode) {
        case 37: index += 1; d3.event.preventDefault(); break // left
        case 39: index -= 1; d3.event.preventDefault(); break // right
        }

        if (index > maxIndex) { index = 0 }
        else if (index < 0) { index = maxIndex }

        update()
      })

    charts.on('mousemove', function () {
      index = maxIndex - Math.max(Math.floor((d3.event.offsetX) / x.step()), 0)
      update()
    })
  }

  function resize() {
    var testNode = d3.select('.data-chart').node()
    var width = testNode.offsetWidth - 2
    var height = testNode.offsetHeight - 2

    x.range([width, 0])

    charts
      .attr('width', width)
      .attr('height', height)
      .each(function () { y.get(this).range([2, height / 2]) })

    bars
      .attr('x', function (d, i) { return x(i) })
      .attr('y', function (d) { return height - y.get(this)(d || 0) })
      .attr('width', x.bandwidth())
      .attr('height', function (d) { return y.get(this)(d || 0) })

    update()
  }

  function update() {
    values.text(function (d) { return d.values[index] })
    rates.html(function (d) { return rateFormat(d.values[index]) })
    times.html(function (d) { return timeFormat(d.values[index]) })
    dates.text('for ' + dateStrings[index])
    bars.attr('opacity', function (d, i) { return i === index ? 0.67 : 0.33 })

    rows = tables.selectAll('tr')
      .data(function (d) { return d.values[index] })

    var enterRows = rows.enter().append('tr')
    enterRows.append('td').attr('class', 'id')
    enterRows.append('td').attr('class', 'count')

    rows.exit().remove()

    rows = rows.merge(enterRows)

    rows.each(function (d) {
      var row = d3.select(this);

      row.select('.id').text(d.id)
      row.select('.count').text(d.count + (d.count === 1 ? ' Download' : ' Downloads'))
    })
  }

  function setDataByKey(sel) {
    return sel.datum(function () {
      var mapper,
        key = d3.select(this).attr('data-key'),
        keys = key.split('/'),
        isRate = false

      if (keys.length === 2) {
        isRate = true
        mapper = function (d) { return d.value[keys[1]] === 0 ? null : d.value[keys[0]] / d.value[keys[1]] }
      } else {
        mapper = function (d) { return d.value[key] }
      }

      return {
        key: key,
        isRate: isRate,
        values: data.map(mapper)
      }
    })
  }

  var format = d3.format('.2f')
  function rateFormat(n) {
    return (n === null ? '??' : Math.round(n * 100)) +
      ' <span class="cf-stat-unit">%</span>'
  }
  function timeFormat(seconds) {
    return !seconds ? '?? <span class="cf-stat-unit">sec</span>' :
      seconds > 60 ? format(seconds / 60) + ' <span class="cf-stat-unit">min</span>' :
      format(seconds) + ' <span class="cf-stat-unit">sec</span>'
  }

  // public
  return {
    init: init
  }
})(d3, moment)
