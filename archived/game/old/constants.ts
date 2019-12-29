// todo: split these out into separate constant files per section of code

// engine config
export const SCALE: number = 2;
export const ORIGIN_X: number = 0;
export const ORIGIN_Y: number = 1;
export const TILE_WIDTH: number = 64;
export const TILE_HEIGHT: number = 32;
export const LAYER_OFFSET: number = 24;
export const MAP_SIZE: number = 128;
export const TILE_ATLAS: string = 'tiles';
export const CAMERA_NAME: string = 'viewport';


// paths
export const ASSETS_PATH: string = '/import/';
export const CITIES_PATH: string = '/cities/';


// event types
export const E_POINTER_OVER: string = 'pointerover';
export const E_POINTER_OUT: string = 'pointerout';
export const E_POINTER_MOVE: string = 'pointermove';
export const E_POINTER_DOWN: string = 'pointerdown';
export const E_POINTER_UP: string = 'pointerup';
export const E_RESIZE: string = 'resize';
export const E_LOAD_COMPLETE: string = 'postprocess';
export const E_MAP_LAYER_HIDE: string = 'mapLayerHide';
export const E_MAP_LAYER_SHOW: string = 'mapLayerShow';


// tile types
export const T_SUBWAY: string = 'subway';
export const T_PIPE: string = 'pipe';
export const T_UNDERGROUND: string = 'underground';
export const T_EDGE: string = 'edge';
export const T_HEIGHTMAP: string = 'heightmap';
export const T_TERRAIN: string = 'terrain';
export const T_WATER: string = 'water';
export const T_ROAD: string = 'road';
export const T_RAIL: string = 'rail';
export const T_POWER: string = 'power';
export const T_HIGHWAY: string = 'highway';
export const T_ZONE: string = 'zone';
export const T_BUILDING: string = 'building';


// visible tile type id
export const T_TERRAIN_ID: number = 0;
export const T_WATER_ID: number = 1;
export const T_ROAD_ID: number = 2;
export const T_RAIL_ID: number = 3;
export const T_POWER_ID: number = 4;
export const T_HIGHWAY_ID: number = 5;
export const T_ZONE_ID: number = 6;
export const T_BUILDING_ID: number = 7;


// additional types
export const T_HIGHWAY_TRAFFIC: string = 'highwayTraffic';
export const T_ROAD_TRAFFIC: string = 'roadTraffic';


// tile relative depths
export const DEPTH_SUBWAY: number = 2;
export const DEPTH_PIPE: number = 4;
export const DEPTH_UNDERGROUND: number = 6;
export const DEPTH_EDGE: number = 8;
export const DEPTH_HEIGHTMAP: number = 10;
export const DEPTH_TERRAIN: number = 12;
export const DEPTH_WATER: number = 14;
export const DEPTH_ROAD: number = 16;
export const DEPTH_RAIL: number = 18;
export const DEPTH_POWER: number = 20;
export const DEPTH_HIGHWAY: number = 22;
export const DEPTH_ZONE: number = 24;
export const DEPTH_BUILDING: number = 26;


// terrain types
export const TERRAIN_SURFACE: string = 'surface';
export const TERRAIN_WATERFALL: string = 'waterfall';
export const TERRAIN_SUBMERGED: string = 'submerged';
export const TERRAIN_SHORE: string = 'shore';
export const TERRAIN_DRY: string = 'dry';
export const TERRAIN_WATER: string = 'water';
export const TERRAIN_BEDROCK: string = 'bedrock';


// directions
export const D_NORTH: string = 'n';
export const D_SOUTH: string = 's';
export const D_EAST: string = 'e';
export const D_WEST: string = 'w';


// corner key tiles
export const CORNER_TOP: string = 'top';
export const CORNER_LEFT: string = 'left';
export const CORNER_BOTTOM: string = 'bottom';
export const CORNER_RIGHT: string = 'right';


// misc
export const ALTERNATE_TILE: string = 'alternateTile';


// tools
export const TOOL_QUERY: string = 'query';
export const TOOL_CENTER: string = 'center';
export const TOOL_ROADS: string = 'roads';


// file identifiers
export const CITY: string = 'CITY';
export const PAL_MSTR_BMP: string = 'PAL_MSTR_BMP';
export const LARGE_DAT: string = 'LARGE_DAT';


// sc2k files to import
export const FILE_PAL_MSTR_BMP: string = 'PAL_MSTR.BMP';
export const FILE_LARGE_DAT: string = 'LARGE.DAT';

// sc2k sha1 hashes
// windows 95 special edition version x.y