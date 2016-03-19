import React from 'react';
import ReactDOM from 'react-dom';

import localforage from 'localforage';
import moment from 'moment';
import { Table, sortColumn } from 'reactabular';
import { orderBy } from 'lodash';

/* -------------------------------------------------------------------------- */

const FilterableBugList = React.createClass({
  getInitialState: function() {
    return {
      bugs: [],
      openOnly: true
    }
  },

  componentDidMount: function() {
    let bz_api = 'https://bugzilla.mozilla.org/rest';
    let bz_fields = ['id', 'summary', 'status', 'resolution', 'is_open',
                     'dupe_of', 'keywords', 'whiteboard', 'product',
                     'component', 'creator', 'creator_detail', 'creation_time',
                     'last_change_time'];
    let bz_url = bz_api + '/bug?keywords=DevAdvocacy&include_fields=' + bz_fields.join(',');

    let setState = (newState) => this.setState(Object.assign({}, this.state, { bugs: newState.bugs }));

    function fetchAndStore(url) {
      return fetch(url)
             .then(response => response.json())
             .then(json => Promise.all([
               localforage.setItem('data', json),
               localforage.setItem('time', Date.now())
             ]))
             .then(([data, time]) => data)
    }

    Promise.all([localforage.getItem('data'), localforage.getItem('time')])
    .then(([data, time]) => {
      let age = Date.now() - time;
      let day = 24 * 60 * 60 * 1000;

      if (!data) {
        console.info("No cached data, fetching...");
        return fetchAndStore(bz_url);
      } else if (age >= day) {
        console.info("Displaying stale cached data, fetching fresh data...");
        setState(data);
        return fetchAndStore(bz_url);
      } else {
        console.info("Displaying fresh cached data, not fetching.");
        return data;
      }
    })
    .then(data => setState(data))
  },

  handleUserInput: function(openOnly) {
    this.setState(Object.assign({}, this.state, { openOnly }));
  },

  render: function() {
    return (
      <div>
        <FilterBar
          openOnly={this.state.openOnly}
          onUserInput={this.handleUserInput}
        />
        <BugTable openOnly={this.state.openOnly} bugs={this.state.bugs} />
      </div>
    );
  }
});

const FilterBar = React.createClass({
  handleChange: function() {
    this.props.onUserInput(this.refs.openOnlyInput.checked);
  },
  render: function() {
    return (
      <form>
        <label>
          <input type='checkbox' checked={this.props.openOnly} onChange={this.handleChange} ref='openOnlyInput' />
          {' '}
          Only show open bugs
        </label>
      </form>
    );
  }
});

const BugTable = React.createClass({
  getInitialState: function() {
    let columns = [
      { property: 'id', header: 'ID', cell: (id) => (
          <a href={`https://bugzilla.mozilla.org/show_bug.cgi?id=${id}`} target="_blank">{id}</a>
      )},
      { property: 'summary', header: 'Summary' },
      { property: 'status', header: 'Status' },
      { property: 'resolution', header: 'Resolution' },
      { property: 'product', header: 'Product' },
      { property: 'component', header: 'Component' },
      { property: 'creation_time', header: 'Age',
          cell: (date) => moment(date).fromNow(true) }
    ];

    return { sortingColumn: undefined, columns: columns}
  },

  render: function() {
    let columns = this.state.columns;

    let row = (row) => ({ "data-open": row.is_open });

    let bugs = this.props.bugs;
    if (this.props.openOnly) {
      bugs = bugs.filter(bug => bug.is_open);
    }

    let totalBugs = this.props.bugs.length;
    let openBugs = this.props.bugs.filter(bug => bug.is_open).length;

    let columnNames = {
      onClick: (column) => {
        sortColumn(
          this.state.columns,
          column,
          this.setState.bind(this)
        );
      },
    }


    let data = sortColumn.sort(bugs, this.state.sortingColumn, orderBy);

    return (
      <div>
        <h1>DevAdvocacy Bugs (Open: {openBugs} / {totalBugs})</h1>
        <Table columns={columns} row={row} data={data} columnNames={columnNames} />
      </div>
    )
  }
});

/* -------------------------------------------------------------------------- */

ReactDOM.render(
  <FilterableBugList />,
  document.getElementById('app')
)