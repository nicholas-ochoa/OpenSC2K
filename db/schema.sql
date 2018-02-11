create table tiles (
  id             integer     not null,

  type           text        not null,
  name           text,
  description    text,
  lot_size       text        default '1x1',

  image          text        not null,
  frames         integer     default 0 not null,
  slopes         text,
  polygon        text,
  lines          text,

  rotate_0       integer,
  rotate_1       integer,
  rotate_2       integer,
  rotate_3       integer,

  flip_h         text,
  flip_alt_tile  text,

  primary key (id)
);


create table city (
  id             integer     not null,
  name           text,
  tiles_x        integer     default 128 not null,
  tiles_y        integer     default 128 not null,
  rotation       number,
  year_founded   number,
  days_elapsed   number,
  money          number,
  population     number,
  water_level    number,

  primary key (id)
);

create table map (
  x                     integer not null,
  y                     integer not null,
  z                     integer not null,

  city_id               integer not null,

  terrain_tile_id       integer default 0 not null,
  zone_tile_id          integer,
  underground_tile_id   integer,
  building_tile_id      integer,

  building_corners      text default '[0,0,0,0]',
  zone_type             integer default 0,
  water_level           text,
  surface_water         text default 'N' not null,

  conductive            text default 'N' not null,
  powered               text default 'N' not null,
  piped                 text default 'N' not null,
  watered               text default 'N' not null,
  land_value            text default 'N' not null,
  water_covered         text default 'N' not null,
  rotate                text default 'N' not null,
  salt_water            text default 'N' not null,

  subway                text default 'N' not null,
  subway_station        text default 'N' not null,
  subway_direction      text,
  pipes                 text default 'N' not null,


  primary key (city_id, x, y),

  foreign key (city_id) references city (id),

  foreign key (terrain_tile_id) references tiles (id),
  foreign key (zone_tile_id) references tiles (id),
  foreign key (underground_tile_id) references tiles (id),
  foreign key (building_tile_id) references tiles (id)
);