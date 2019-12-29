// todo: split these out into separate constant files per section of code

// engine config
export const SCALE          = 2;
export const ORIGIN_X       = 0;
export const ORIGIN_Y       = 1;
export const TILE_WIDTH     = 64;
export const TILE_HEIGHT    = 32;
export const LAYER_OFFSET   = 24;
export const MAP_SIZE       = 128;
export const TILE_ATLAS     = 'tiles';
export const CAMERA_NAME    = 'viewport';


// paths
export const ASSETS_PATH    = '/assets/import/';
export const CITIES_PATH    = '/assets/cities/';


// event types
export const E_POINTER_OVER   = 'pointerover';
export const E_POINTER_OUT    = 'pointerout';
export const E_POINTER_MOVE   = 'pointermove';
export const E_POINTER_DOWN   = 'pointerdown';
export const E_POINTER_UP     = 'pointerup';
export const E_RESIZE         = 'resize';
export const E_LOAD_COMPLETE  = 'postprocess';
export const E_MAP_LAYER_HIDE = 'mapLayerHide';
export const E_MAP_LAYER_SHOW = 'mapLayerShow';


// tile types
export const T_SUBWAY       = 'subway';
export const T_PIPE         = 'pipe';
export const T_UNDERGROUND  = 'underground';
export const T_EDGE         = 'edge';
export const T_HEIGHTMAP    = 'heightmap';
export const T_TERRAIN      = 'terrain';
export const T_WATER        = 'water';
export const T_ROAD         = 'road';
export const T_RAIL         = 'rail';
export const T_POWER        = 'power';
export const T_HIGHWAY      = 'highway';
export const T_ZONE         = 'zone';
export const T_BUILDING     = 'building';


// visible tile type id
export const T_TERRAIN_ID   = 0;
export const T_WATER_ID     = 1;
export const T_ROAD_ID      = 2;
export const T_RAIL_ID      = 3;
export const T_POWER_ID     = 4;
export const T_HIGHWAY_ID   = 5;
export const T_ZONE_ID      = 6;
export const T_BUILDING_ID  = 7;


// additional types
export const T_HIGHWAY_TRAFFIC = 'highwayTraffic';
export const T_ROAD_TRAFFIC    = 'roadTraffic';


// tile relative depths
export const DEPTH_SUBWAY       = 2;
export const DEPTH_PIPE         = 4;
export const DEPTH_UNDERGROUND  = 6;
export const DEPTH_EDGE         = 8;
export const DEPTH_HEIGHTMAP    = 10;
export const DEPTH_TERRAIN      = 12;
export const DEPTH_WATER        = 14;
export const DEPTH_ROAD         = 16;
export const DEPTH_RAIL         = 18;
export const DEPTH_POWER        = 20;
export const DEPTH_HIGHWAY      = 22;
export const DEPTH_ZONE         = 24;
export const DEPTH_BUILDING     = 26;


// terrain types
export const TERRAIN_SURFACE    = 'surface';
export const TERRAIN_WATERFALL  = 'waterfall';
export const TERRAIN_SUBMERGED  = 'submerged';
export const TERRAIN_SHORE      = 'shore';
export const TERRAIN_DRY        = 'dry';
export const TERRAIN_WATER      = 'water';
export const TERRAIN_BEDROCK    = 'bedrock';


// directions
export const D_NORTH            = 'n';
export const D_SOUTH            = 's';
export const D_EAST             = 'e';
export const D_WEST             = 'w';


// corner key tiles
export const CORNER_TOP         = 'top';
export const CORNER_LEFT        = 'left';
export const CORNER_BOTTOM      = 'bottom';
export const CORNER_RIGHT       = 'right';


// misc
export const ALTERNATE_TILE     = 'alternateTile';


// tools
export const TOOL_QUERY         = 'query';
export const TOOL_CENTER        = 'center';
export const TOOL_ROADS         = 'roads';


// file identifiers
export const CITY               = 'CITY';
export const PAL_MSTR_BMP       = 'PAL_MSTR_BMP';
export const LARGE_DAT          = 'LARGE_DAT';


// sc2k files to import
export const FILE_PAL_MSTR_BMP = 'PAL_MSTR.BMP';
export const FILE_LARGE_DAT    = 'LARGE.DAT';

// sc2k sha1 hashes
// windows 95 special edition version x.y