#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Mojo::Pg;
use DDP;

helper pg => sub { state $pg = Mojo::Pg->new('postgresql://log_parser_user:1234567@localhost/log_parser') };

get '/' => sub ($c) {
  $c->render(template => 'index');
};

post '/search/address' => sub($c) {
  my $param = $c->req->json;

  return $c->render(json => {error => 1}, status => 400) if !$param->{address} || $param->{address} !~ /^\S+@\S+$/;

  my $db = $c->pg->db;
  my $log_data_collection = $db->query(q|
    WITH log_data AS (
      SELECT int_id, created, str FROM log WHERE address = ?
    )
    SELECT int_id, created, str, COUNT(*) OVER() AS total_count
    FROM (
      (SELECT int_id, created, str FROM log_data)
      UNION ALL
      (SELECT int_id, created, str FROM message m WHERE m.int_id IN (SELECT ld.int_id FROM log_data ld))
      ORDER BY created, int_id
    ) AS ld
    LIMIT 100
    |, $param->{address})->hashes;

  my ($count_rows, $log_data) = (0, []);
  if ($log_data_collection && (my @log_data_arr = $log_data_collection->to_array->@*)) {
    $count_rows = $log_data_arr[0]->{total_count};
    $log_data = [map { +{created => $_->{created}, str => $_->{str}} } @log_data_arr];
  }

  return $c->render(json => {log_data => $log_data, count_rows => $count_rows});
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Поиск данных в логе';
<div id="app" v-cloak>
  <form class="search-address" @submit.prevent="onSubmit">
    <ul class="wrapper">
      <li class="form-row">
        <label for="address">Address</label>
        <input type="text" v-model="address">
      </li>
      <li class="form-row">
        <button type="submit">Submit</button>
      </li>
    </ul>
  </form>

  <div v-if="count_rows > 100">Общее количество строк в логе: {{ count_rows }}, в таблице выведено только 100 строк</div>
  <table v-if="count_rows" class="table">
    <thead>
      <tr>
        <th>Timestamp</th>
        <th>Строка лога</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="data in log_data">
        <td>{{ data.created }}</td>
        <td>{{ data.str }}</td>
      </tr>
    </tbody>
  </table>
</div>
<script src="https://unpkg.com/vue@next"></script>
<script src="search-address.js"></script>

@@ search-address.js
const SearchAddressApp = {
  data() {
    return {
      address: '',
      log_data: [],
      count_rows: 0,
    }
  },
  methods: {
    async onSubmit() {
      console.log(this.address);

      let response = await fetch('/search/address', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json;charset=utf-8'
        },
        body: JSON.stringify({address: this.address})
      });

      let result = await response.json();
      this.log_data = result.log_data;
      this.count_rows = result.count_rows;
    }
  }
}

Vue.createApp(SearchAddressApp).mount('#app')

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <style>
      .wrapper {
        background-color: whitesmoke;
        list-style-type: none;
        padding: 0;
        border-radius: 3px;
      }
      .form-row {
        display: flex;
        justify-content: flex-end;
        padding: .5em;
      }
      .form-row > label {
        padding: .5em 1em .5em 0;
        flex: 1;
      }
      .form-row > input {
        flex: 2;
      }
      .form-row > input,
      .form-row > button {
        padding: .5em;
      }
      .form-row > button {
       background: gray;
       color: white;
       border: 0;
      }

      .table {
        width: 100%;
        margin-bottom: 20px;
        border: 1px solid #dddddd;
        border-collapse: collapse; 
      }
      .table th {
        font-weight: bold;
        padding: 5px;
        background: #efefef;
        border: 1px solid #dddddd;
      }
      .table td {
        border: 1px solid #dddddd;
        padding: 5px;
      }

      [v-cloak] {
        display: none;
      }
    </style>
  </head>
  <body><%= content %></body>
</html>
