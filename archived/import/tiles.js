var data = [
  {
    id: 0,
    type: null,
    description: null,
    size: 0,
    image: null
  },
  {
    id: 1,
    type: 'building',
    subtype: 'landscape',
    description: 'Rubble',
    size: 1,
    image: '1001',
    requiresTerrain: true,
  },
  {
    id: 2,
    type: 'building',
    subtype: 'landscape',
    description: 'Rubble',
    size: 1,
    image: '1002',
    requiresTerrain: true,
  },
  {
    id: 3,
    type: 'building',
    subtype: 'landscape',
    description: 'Rubble',
    size: 1,
    image: '1003',
    requiresTerrain: true,
  },
  {
    id: 4,
    type: 'building',
    subtype: 'landscape',
    description: 'Rubble',
    size: 1,
    image: '1004',
    requiresTerrain: true,
  },
  {
    id: 5,
    type: 'building',
    subtype: 'landscape',
    description: 'Radioactive waste',
    size: 1,
    image: '1005',
    requiresTerrain: true,
  },
  {
    id: 6,
    type: 'building',
    subtype: 'landscape',
    description: 'Trees',
    size: 1,
    image: '1006',
    requiresTerrain: true,
  },
  {
    id: 7,
    type: 'building',
    subtype: 'landscape',
    description: 'Trees',
    size: 1,
    image: '1007',
    requiresTerrain: true,
  },
  {
    id: 8,
    type: 'building',
    subtype: 'landscape',
    description: 'Trees',
    size: 1,
    image: '1008',
    requiresTerrain: true,
  },
  {
    id: 9,
    type: 'building',
    subtype: 'landscape',
    description: 'Trees',
    size: 1,
    image: '1009',
    requiresTerrain: true,
  },
  {
    id: 10,
    type: 'building',
    description: 'Trees',
    size: 1,
    image: '1010',
    requiresTerrain: true,
  },
  {
    id: 11,
    type: 'building',
    subtype: 'landscape',
    description: 'Trees',
    size: 1,
    image: '1011',
    requiresTerrain: true,
  },
  {
    id: 12,
    type: 'building',
    subtype: 'landscape',
    description: 'Trees',
    size: 1,
    image: '1012',
    requiresTerrain: true,
  },
  {
    id: 13,
    type: 'building',
    description: 'Small park',
    size: 1,
    image: '1013',
  },
  {
    id: 14,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1014',
    rotate: [14, 15, 14, 15],
  },
  {
    id: 15,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1015',
    rotate: [15, 14, 15, 14],
  },
  {
    id: 16,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1016',
    rotate: [16, 17, 18, 19],
  },
  {
    id: 17,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1017',
    rotate: [17, 18, 19, 16],
  },
  {
    id: 18,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1018',
    rotate: [18, 19, 16, 17],
  },
  {
    id: 19,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1019',
    rotate: [19, 16, 17, 18],
  },
  {
    id: 20,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1020',
    rotate: [20, 21, 22, 23],
  },
  {
    id: 21,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1021',
    rotate: [21, 22, 23, 20],
  },
  {
    id: 22,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1022',
    rotate: [22, 23, 20, 21],
  },
  {
    id: 23,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1023',
    rotate: [23, 20, 21, 22],
  },
  {
    id: 24,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1024',
    rotate: [24, 25, 26, 27],
  },
  {
    id: 25,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1025',
    rotate: [25, 26, 27, 24],
  },
  {
    id: 26,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1026',
    rotate: [26, 27, 24, 25],
  },
  {
    id: 27,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1027',
    rotate: [27, 24, 25, 26],
  },
  {
    id: 28,
    type: 'power',
    description: 'Power lines',
    size: 1,
    image: '1028',
  },
  {
    id: 29,
    type: 'road',
    description: 'Road (straight)',
    size: 1,
    image: '1029',
    rotate: [29, 30, 29, 30],
    simulation: 'traffic',
    traffic: {
      light: 400,
      heavy: 427
    }
  },
  {
    id: 30,
    type: 'road',
    description: 'Road (straight)',
    size: 1,
    image: '1030',
    rotate: [30, 29, 30, 29],
    simulation: 'traffic',
    traffic: {
      light: 401,
      heavy: 428
    }
  },
  {
    id: 31,
    type: 'road',
    description: 'Road (sloped)',
    size: 1,
    image: '1031',
    rotate: [31, 32, 33, 34],
    simulation: 'traffic',
    traffic: {
      light: 402,
      heavy: 429
    }
  },
  {
    id: 32,
    type: 'road',
    description: 'Road (sloped)',
    size: 1,
    image: '1032',
    rotate: [32, 33, 34, 31],
    simulation: 'traffic',
    traffic: {
      light: 403,
      heavy: 430
    }
  },
  {
    id: 33,
    type: 'road',
    description: 'Road (sloped)',
    size: 1,
    image: '1033',
    rotate: [33, 34, 31, 32],
    simulation: 'traffic',
    traffic: {
      light: 404,
      heavy: 431
    }
  },
  {
    id: 34,
    type: 'road',
    description: 'Road (sloped)',
    size: 1,
    image: '1034',
    rotate: [34, 31, 32, 33],
    simulation: 'traffic',
    traffic: {
      light: 405,
      heavy: 432
    }
  },
  {
    id: 35,
    type: 'road',
    description: 'Road (curve)',
    size: 1,
    image: '1035',
    rotate: [35, 36, 37, 38],
    simulation: 'traffic',
    traffic: {
      light: 406,
      heavy: 433
    }
  },
  {
    id: 36,
    type: 'road',
    description: 'Road (curve)',
    size: 1,
    image: '1036',
    rotate: [36, 37, 38, 35],
    simulation: 'traffic',
    traffic: {
      light: 407,
      heavy: 434
    }
  },
  {
    id: 37,
    type: 'road',
    description: 'Road (curve)',
    size: 1,
    image: '1037',
    rotate: [37, 38, 35, 36],
    simulation: 'traffic',
    traffic: {
      light: 408,
      heavy: 435
    }
  },
  {
    id: 38,
    type: 'road',
    description: 'Road (curve)',
    size: 1,
    image: '1038',
    rotate: [38, 35, 36, 37],
    simulation: 'traffic',
    traffic: {
      light: 409,
      heavy: 436
    }
  },
  {
    id: 39,
    type: 'road',
    description: 'Road (3 way intersection)',
    size: 1,
    image: '1039',
    rotate: [39, 40, 41, 42],
    simulation: 'traffic',
    traffic: {
      light: 401,
      heavy: 428
    }
  },
  {
    id: 40,
    type: 'road',
    description: 'Road (3 way intersection)',
    size: 1,
    image: '1040',
    rotate: [40, 41, 42, 39],
    simulation: 'traffic',
    traffic: {
      light: 400,
      heavy: 427
    }
  },
  {
    id: 41,
    type: 'road',
    description: 'Road (3 way intersection)',
    size: 1,
    image: '1041',
    rotate: [41, 42, 39, 40],
    simulation: 'traffic',
    traffic: {
      light: 401,
      heavy: 428
    }
  },
  {
    id: 42,
    type: 'road',
    description: 'Road (3 way intersection)',
    size: 1,
    image: '1042',
    rotate: [42, 39, 40, 41],
    simulation: 'traffic',
    traffic: {
      light: 400,
      heavy: 427
    }
  },
  {
    id: 43,
    type: 'road',
    description: 'Road (4 way intersection)',
    size: 1,
    image: '1043',
    simulation: 'traffic',
    traffic: {
      light: 401,
      heavy: 428
    }
  },
  {
    id: 44,
    type: 'rail',
    description: 'Rails (straight)',
    size: 1,
    image: '1044',
    rotate: [44, 45, 44, 45],
  },
  {
    id: 45,
    type: 'rail',
    description: 'Rails (straight)',
    size: 1,
    image: '1045',
    rotate: [45, 44, 45, 44],
  },
  {
    id: 46,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1046',
    rotate: [46, 47, 48, 49],
  },
  {
    id: 47,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1047',
    rotate: [47, 48, 49, 46],
  },
  {
    id: 48,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1048',
    rotate: [48, 49, 46, 47],
  },
  {
    id: 49,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1049',
    rotate: [49, 46, 47, 48],
  },
  {
    id: 50,
    type: 'rail',
    description: 'Rails (curve)',
    size: 1,
    image: '1050',
    rotate: [50, 51, 52, 53],
  },
  {
    id: 51,
    type: 'rail',
    description: 'Rails (curve)',
    size: 1,
    image: '1051',
    rotate: [51, 52, 53, 50],
  },
  {
    id: 52,
    type: 'rail',
    description: 'Rails (curve)',
    size: 1,
    image: '1052',
    rotate: [52, 53, 50, 51],
  },
  {
    id: 53,
    type: 'rail',
    description: 'Rails (curve)',
    size: 1,
    image: '1053',
    rotate: [53, 50, 51, 52],
  },
  {
    id: 54,
    type: 'rail',
    description: 'Rails (junction)',
    size: 1,
    image: '1054',
    rotate: [54, 55, 56, 57],
  },
  {
    id: 55,
    type: 'rail',
    description: 'Rails (junction)',
    size: 1,
    image: '1055',
    rotate: [55, 56, 57, 54],
  },
  {
    id: 56,
    type: 'rail',
    description: 'Rails (junction)',
    size: 1,
    image: '1056',
    rotate: [56, 57, 54, 55],
  },
  {
    id: 57,
    type: 'rail',
    description: 'Rails (junction)',
    size: 1,
    image: '1057',
    rotate: [57, 54, 55, 56],
  },
  {
    id: 58,
    type: 'rail',
    description: 'Rails (X junction)',
    size: 1,
    image: '1058',
  },
  {
    id: 59,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1059',
    rotate: [59, 60, 61, 62],
  },
  {
    id: 60,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1060',
    rotate: [60, 61, 62, 59],
  },
  {
    id: 61,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1061',
    rotate: [61, 62, 59, 60],
  },
  {
    id: 62,
    type: 'rail',
    description: 'Rails (slope)',
    size: 1,
    image: '1062',
    rotate: [62, 59, 60, 61],
  },
  {
    id: 63,
    type: 'road',
    description: 'Tunnel entrance (south)',
    size: 1,
    image: '1063',
    rotate: [63, 64, 65, 66],
    depthAdjustment: -1,
  },
  {
    id: 64,
    type: 'road',
    description: 'Tunnel entrance',
    size: 1,
    image: '1064',
    rotate: [64, 65, 66, 63],
    depthAdjustment: -1,
  },
  {
    id: 65,
    type: 'road',
    description: 'Tunnel entrance (north)',
    size: 1,
    image: '1065',
    rotate: [65, 66, 63, 64],
    depthAdjustment: -1,
  },
  {
    id: 66,
    type: 'road',
    description: 'Tunnel entrance',
    size: 1,
    image: '1066',
    rotate: [66, 63, 64, 65],
    depthAdjustment: -1,
  },
  {
    id: 67,
    type: 'power',
    subtype: 'road',
    description: 'Road / power lines',
    size: 1,
    image: '1067',
    rotate: [67, 68, 67, 68],
    baseLayer: 29,
    importOptions: {
      dropColor: [124, 155, 161]
    }
  },
  {
    id: 68,
    type: 'power',
    subtype: 'road',
    description: 'Road / power lines',
    size: 1,
    image: '1068',
    rotate: [68, 67, 68, 67],
    baseLayer: 30,
    importOptions: {
      dropColor: [124, 155, 161]
    }
  },
  {
    id: 69,
    type: 'road',
    subtype: 'rail',
    description: 'Road / rails',
    size: 1,
    image: '1069',
    rotate: [69, 70, 69, 70],
  },
  {
    id: 70,
    type: 'road',
    subtype: 'rail',
    description: 'Road / rails',
    size: 1,
    image: '1070',
    rotate: [70, 69, 70, 69],
  },
  {
    id: 71,
    type: 'rail',
    subtype: 'power',
    description: 'Rails / power lines',
    size: 1,
    image: '1071',
    rotate: [71, 72, 71, 72],
  },
  {
    id: 72,
    type: 'rail',
    subtype: 'power',
    description: 'Rails / power lines',
    size: 1,
    image: '1072',
    rotate: [72, 71, 72, 71],
  },
  {
    id: 73,
    type: 'highway',
    description: 'Highway (straight)',
    direction: 'ns',
    size: 1,
    image: '1073',
    rotate: [73, 74, 73, 74],
    simulation: 'traffic',
    traffic: {
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 74,
    type: 'highway',
    description: 'Highway (straight)',
    direction: 'ew',
    size: 1,
    image: '1074',
    rotate: [74, 73, 74, 73],
    simulation: 'traffic',
    traffic: {
      flip: true,
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 75,
    type: 'highway',
    subtype: 'road',
    description: 'Highway / road',
    direction: 'ns',
    size: 1,
    image: '1075',
    rotate: [75, 76, 75, 76],
    simulation: 'traffic',
    traffic: {
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 76,
    type: 'highway',
    subtype: 'road',
    description: 'Highway / road',
    direction: 'ew',
    size: 1,
    image: '1076',
    rotate: [76, 75, 76, 75],
    simulation: 'traffic',
    traffic: {
      flip: true,
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 77,
    type: 'highway',
    subtype: 'rail',
    description: 'Highway / rails',
    direction: 'ns',
    size: 1,
    image: '1077',
    rotate: [77, 78, 77, 78],
    simulation: 'traffic',
    traffic: {
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 78,
    type: 'highway',
    subtype: 'rail',
    description: 'Highway / rails',
    direction: 'ew',
    size: 1,
    image: '1078',
    rotate: [78, 77, 78, 77],
    simulation: 'traffic',
    traffic: {
      flip: true,
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 79,
    type: 'highway',
    subtype: 'power',
    description: 'Highway / power lines',
    direction: 'ns',
    size: 1,
    image: '1079',
    rotate: [79, 80, 79, 80],
    simulation: 'traffic',
    traffic: {
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 80,
    type: 'highway',
    subtype: 'power',
    description: 'Highway / power lines',
    direction: 'ew',
    size: 1,
    image: '1080',
    rotate: [80, 79, 80, 79],
    simulation: 'traffic',
    traffic: {
      flip: true,
      light: [410, 411],
      heavy: [437, 438],
    },
  },
  {
    id: 81,
    type: 'road',
    description: 'Suspension bridge',
    size: 1,
    image: '1081',
    rotate: [81, 85, 81, 85],
    flip: true,
    flipMode: 'alternateTile',
    bridge: true,
  },
  {
    id: 82,
    type: 'road',
    description: 'Suspension bridge',
    size: 1,
    image: '1082',
    rotate: [82, 84, 82, 84],
    flip: true,
    flipMode: 'alternateTile',
    bridge: true,
  },
  {
    id: 83,
    type: 'road',
    description: 'Suspension bridge',
    size: 1,
    image: '1083',
    rotate: [83, 83, 83, 83],
    flip: true,
    flipMode: 'alternateTile',
    bridge: true,
  },
  {
    id: 84,
    type: 'road',
    description: 'Suspension bridge',
    size: 1,
    image: '1084',
    rotate: [84, 82, 84, 82],
    flip: true,
    flipMode: 'alternateTile',
    bridge: true,
  },
  {
    id: 85,
    type: 'road',
    description: 'Suspension bridge',
    size: 1,
    image: '1085',
    rotate: [85, 81, 85, 81],
    flip: true,
    flipMode: 'alternateTile',
    bridge: true,
  },
  {
    id: 86,
    type: 'road',
    description: 'Road (Bridge Lift)',
    size: 1,
    image: '1086',
    flip: true,
    bridge: true,
  },
  {
    id: 87,
    type: 'road',
    description: 'Road (Causeway)',
    size: 1,
    image: '1087',
    flip: true,
    bridge: true,
    simulation: 'traffic',
    traffic: {
      light: 400,
      heavy: 427,
    },
  },
  {
    id: 88,
    type: 'road',
    description: 'Road (Bridge Down)',
    size: 1,
    image: '1088',
    flip: true,
    bridge: true,
    simulation: 'traffic',
    traffic: {
      light: 400,
      heavy: 427,
    },
  },
  {
    id: 89,
    type: 'road',
    description: 'Road (Bridge Up)',
    size: 1,
    image: '1089',
    flip: true,
    bridge: true,
  },
  {
    id: 90,
    type: 'rail',
    description: 'Rail bridge',
    size: 1,
    image: '1090',
    flip: true,
    bridge: true,
  },
  {
    id: 91,
    type: 'rail',
    description: 'Rail bridge',
    size: 1,
    image: '1091',
    flip: true,
    bridge: true,
  },
  {
    id: 92,
    type: 'power',
    description: 'Elevated power lines',
    size: 1,
    image: '1092',
    flip: true,
    bridge: true,
  },
  {
    id: 93,
    type: 'highway',
    description: 'Highway Onramp',
    size: 1,
    image: '1093',
    rotate: [93, 96, 93, 96],
    flip: true,
    flipMode: 'alternateTile',
    simulation: 'highwayTraffic',
    highwayOnramp: true,
    traffic: {
      light: 414,
      heavy: 414,
    },
  },
  {
    id: 94,
    type: 'highway',
    description: 'Highway Onramp',
    size: 1,
    image: '1094',
    rotate: [94, 95, 94, 95],
    flip: true,
    flipMode: 'alternateTile',
    simulation: 'highwayTraffic',
    highwayOnramp: true,
    traffic: {
      light: 415,
      heavy: 415,
    },
  },
  {
    id: 95,
    type: 'highway',
    description: 'Highway Onramp',
    size: 1,
    image: '1095',
    rotate: [95, 94, 95, 94],
    flip: true,
    flipMode: 'alternateTile',
    simulation: 'highwayTraffic',
    highwayOnramp: true,
    traffic: {
      light: 416,
      heavy: 416,
    },
  },
  {
    id: 96,
    type: 'highway',
    description: 'Highway Onramp',
    size: 1,
    image: '1096',
    rotate: [96, 93, 96, 93],
    flip: true,
    flipMode: 'alternateTile',
    simulation: 'highwayTraffic',
    highwayOnramp: true,
    traffic: {
      light: 417,
      heavy: 417,
    },
  },
  {
    id: 97,
    type: 'highway',
    description: 'Highway (Slope)',
    size: 2,
    image: '1097',
    rotate: [97, 98, 99, 100],
    simulation: 'highwayTraffic',
    traffic: {
      light: 418,
      heavy: 441,
    },
  },
  {
    id: 98,
    type: 'highway',
    description: 'Highway (Slope)',
    size: 2,
    image: '1098',
    rotate: [98, 99, 100, 97],
    simulation: 'highwayTraffic',
    traffic: {
      light: 419,
      heavy: 442,
    },
  },
  {
    id: 99,
    type: 'highway',
    description: 'Highway (Slope)',
    size: 2,
    image: '1099',
    rotate: [99, 100, 97, 98],
    simulation: 'highwayTraffic',
    traffic: {
      light: 420,
      heavy: 443,
    },
  },
  {
    id: 100,
    type: 'highway',
    description: 'Highway (Slope)',
    size: 2,
    image: '1100',
    rotate: [100, 97, 98, 99],
    simulation: 'highwayTraffic',
    traffic: {
      light: 421,
      heavy: 444,
    },
  },
  {
    id: 101,
    type: 'highway',
    description: 'Highway (Curve)',
    size: 2,
    image: '1101',
    rotate: [101, 102, 103, 104],
    simulation: 'highwayTraffic',
    traffic: {
      light: 422,
      heavy: 445,
    },
  },
  {
    id: 102,
    type: 'highway',
    description: 'Highway (Curve)',
    size: 2,
    image: '1102',
    rotate: [102, 103, 104, 101],
    simulation: 'highwayTraffic',
    traffic: {
      light: 423,
      heavy: 446,
    },
  },
  {
    id: 103,
    type: 'highway',
    description: 'Highway (Curve)',
    size: 2,
    image: '1103',
    rotate: [103, 104, 101, 102],
    simulation: 'highwayTraffic',
    traffic: {
      light: 424,
      heavy: 447,
    },
  },
  {
    id: 104,
    type: 'highway',
    description: 'Highway (Curve)',
    size: 2,
    image: '1104',
    rotate: [104, 101, 102, 103],
    simulation: 'highwayTraffic',
    traffic: {
      light: 425,
      heavy: 448,
    },
  },
  {
    id: 105,
    type: 'highway',
    description: 'Highway (Cloverleaf)',
    size: 2,
    image: '1105',
    simulation: 'highwayTraffic',
    traffic: {
      light: 426,
      heavy: 449,
    },
  },
  {
    id: 106,
    type: 'highway',
    description: 'Highway (Reinforced Bridge w/ Support)',
    size: 2,
    image: '1106',
    flip: true,
    bridge: true,
  },
  {
    id: 107,
    type: 'highway',
    description: 'Highway (Reinforced Bridge)',
    size: 2,
    image: '1107',
    flip: true,
    bridge: true,
  },
  {
    id: 108,
    type: 'rail',
    subtype: 'subway',
    description: 'Subway <-> Rails Transition',
    size: 1,
    image: '1108',
    rotate: [108, 109, 110, 111],
  },
  {
    id: 109,
    type: 'rail',
    subtype: 'subway',
    description: 'Subway <-> Rails Transition',
    size: 1,
    image: '1109',
    rotate: [109, 110, 111, 108],
  },
  {
    id: 110,
    type: 'rail',
    subtype: 'subway',
    description: 'Subway <-> Rails Transition',
    size: 1,
    image: '1110',
    rotate: [110, 111, 108, 109],
  },
  {
    id: 111,
    type: 'rail',
    subtype: 'subway',
    description: 'Subway <-> Rails Transition',
    size: 1,
    image: '1111',
    rotate: [111, 108, 109, 110],
  },
  {
    id: 112,
    type: 'building',
    description: 'Lower-class homes',
    size: 1,
    image: '1112',
  },
  {
    id: 113,
    type: 'building',
    description: 'Lower-class homes',
    size: 1,
    image: '1113',
  },
  {
    id: 114,
    type: 'building',
    description: 'Lower-class homes',
    size: 1,
    image: '1114',
  },
  {
    id: 115,
    type: 'building',
    description: 'Lower-class homes',
    size: 1,
    image: '1115',
  },
  {
    id: 116,
    type: 'building',
    description: 'Middle-class homes',
    size: 1,
    image: '1116',
  },
  {
    id: 117,
    type: 'building',
    description: 'Middle-class homes',
    size: 1,
    image: '1117',
  },
  {
    id: 118,
    type: 'building',
    description: 'Middle-class homes',
    size: 1,
    image: '1118',
  },
  {
    id: 119,
    type: 'building',
    description: 'Middle-class homes',
    size: 1,
    image: '1119',
  },
  {
    id: 120,
    type: 'building',
    description: 'Luxury homes',
    size: 1,
    image: '1120',
  },
  {
    id: 121,
    type: 'building',
    description: 'Luxury homes',
    size: 1,
    image: '1121',
  },
  {
    id: 122,
    type: 'building',
    description: 'Luxury homes',
    size: 1,
    image: '1122',
  },
  {
    id: 123,
    type: 'building',
    description: 'Luxury homes',
    size: 1,
    image: '1123',
  },
  {
    id: 124,
    type: 'building',
    description: 'Gas station',
    size: 1,
    image: '1124',
  },
  {
    id: 125,
    type: 'building',
    description: 'Bed & breakfast inn',
    size: 1,
    image: '1125',
  },
  {
    id: 126,
    type: 'building',
    description: 'Convenience store',
    size: 1,
    image: '1126',
  },
  {
    id: 127,
    type: 'building',
    description: 'Gas station',
    size: 1,
    image: '1127',
  },
  {
    id: 128,
    type: 'building',
    description: 'Small office building',
    size: 1,
    image: '1128',
  },
  {
    id: 129,
    type: 'building',
    description: 'Office building',
    size: 1,
    image: '1129',
  },
  {
    id: 130,
    type: 'building',
    description: 'Warehouse',
    size: 1,
    image: '1130',
  },
  {
    id: 131,
    type: 'building',
    description: 'Cassidy\'s Toy Store',
    size: 1,
    image: '1131',
  },
  {
    id: 132,
    type: 'building',
    description: 'Warehouse',
    size: 1,
    image: '1132',
  },
  {
    id: 133,
    type: 'building',
    description: 'Chemical storage',
    size: 1,
    image: '1133',
  },
  {
    id: 134,
    type: 'building',
    description: 'Warehouse',
    size: 1,
    image: '1134',
  },
  {
    id: 135,
    type: 'building',
    description: 'Industrial substation',
    size: 1,
    image: '1135',
  },
  {
    id: 136,
    type: 'building',
    description: 'Construction',
    size: 1,
    image: '1136',
  },
  {
    id: 137,
    type: 'building',
    description: 'Construction',
    size: 1,
    image: '1137',
  },
  {
    id: 138,
    type: 'building',
    description: 'Abandoned building',
    size: 1,
    image: '1138',
  },
  {
    id: 139,
    type: 'building',
    description: 'Abandoned building',
    size: 1,
    image: '1139',
  },
  {
    id: 140,
    type: 'building',
    description: 'Cheap apartments',
    size: 2,
    image: '1140',
  },
  {
    id: 141,
    type: 'building',
    description: 'Apartments',
    size: 2,
    image: '1141',
  },
  {
    id: 142,
    type: 'building',
    description: 'Apartments',
    size: 2,
    image: '1142',
  },
  {
    id: 143,
    type: 'building',
    description: 'Nice apartments',
    size: 2,
    image: '1143',
  },
  {
    id: 144,
    type: 'building',
    description: 'Nice apartments',
    size: 2,
    image: '1144',
  },
  {
    id: 145,
    type: 'building',
    description: 'Condominium',
    size: 2,
    image: '1145',
  },
  {
    id: 146,
    type: 'building',
    description: 'Condominium',
    size: 2,
    image: '1146',
  },
  {
    id: 147,
    type: 'building',
    description: 'Condominium',
    size: 2,
    image: '1147',
  },
  {
    id: 148,
    type: 'building',
    description: 'Shopping center',
    size: 2,
    image: '1148',
  },
  {
    id: 149,
    type: 'building',
    description: 'Grocery store',
    size: 2,
    image: '1149',
  },
  {
    id: 150,
    type: 'building',
    description: 'Office building',
    size: 2,
    image: '1150',
  },
  {
    id: 151,
    type: 'building',
    description: 'Resort hotel',
    size: 2,
    image: '1151',
  },
  {
    id: 152,
    type: 'building',
    description: 'Office building',
    size: 2,
    image: '1152',
  },
  {
    id: 153,
    type: 'building',
    description: 'Office / Retail',
    size: 2,
    image: '1153',
  },
  {
    id: 154,
    type: 'building',
    description: 'Office building',
    size: 2,
    image: '1154',
  },
  {
    id: 155,
    type: 'building',
    description: 'Office building',
    size: 2,
    image: '1155',
  },
  {
    id: 156,
    type: 'building',
    description: 'Office building',
    size: 2,
    image: '1156',
  },
  {
    id: 157,
    type: 'building',
    description: 'Office building',
    size: 2,
    image: '1157',
  },
  {
    id: 158,
    type: 'building',
    description: 'Warehouse',
    size: 2,
    image: '1158',
  },
  {
    id: 159,
    type: 'building',
    description: 'Chemical processing',
    size: 2,
    image: '1159',
  },
  {
    id: 160,
    type: 'building',
    description: 'Factory',
    size: 2,
    image: '1160',
  },
  {
    id: 161,
    type: 'building',
    description: 'Factory',
    size: 2,
    image: '1161',
  },
  {
    id: 162,
    type: 'building',
    description: 'Factory',
    size: 2,
    image: '1162',
  },
  {
    id: 163,
    type: 'building',
    description: 'Factory',
    size: 2,
    image: '1163',
  },
  {
    id: 164,
    type: 'building',
    description: 'Factory',
    size: 2,
    image: '1164',
  },
  {
    id: 165,
    type: 'building',
    description: 'Factory',
    size: 2,
    image: '1165',
  },
  {
    id: 166,
    type: 'building',
    description: 'Construction',
    size: 2,
    image: '1166',
  },
  {
    id: 167,
    type: 'building',
    description: 'Construction',
    size: 2,
    image: '1167',
  },
  {
    id: 168,
    type: 'building',
    description: 'Construction',
    size: 2,
    image: '1168',
  },
  {
    id: 169,
    type: 'building',
    description: 'Construction',
    size: 2,
    image: '1169',
  },
  {
    id: 170,
    type: 'building',
    description: 'Abandoned building',
    size: 2,
    image: '1170',
  },
  {
    id: 171,
    type: 'building',
    description: 'Abandoned building',
    size: 2,
    image: '1171',
  },
  {
    id: 172,
    type: 'building',
    description: 'Abandoned building',
    size: 2,
    image: '1172',
  },
  {
    id: 173,
    type: 'building',
    description: 'Abandoned building',
    size: 2,
    image: '1173',
  },
  {
    id: 174,
    type: 'building',
    description: 'Large apartment building',
    size: 3,
    image: '1174',
  },
  {
    id: 175,
    type: 'building',
    description: 'Large apartment building',
    size: 3,
    image: '1175',
  },
  {
    id: 176,
    type: 'building',
    description: 'Condominium',
    size: 3,
    image: '1176',
  },
  {
    id: 177,
    type: 'building',
    description: 'Condominium',
    size: 3,
    image: '1177',
  },
  {
    id: 178,
    type: 'building',
    description: 'Office park',
    size: 3,
    image: '1178',
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 179,
    type: 'building',
    description: 'Office tower',
    size: 3,
    image: '1179',
  },
  {
    id: 180,
    type: 'building',
    description: 'Mini-mall',
    size: 3,
    image: '1180',
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 181,
    type: 'building',
    description: 'Theater square',
    size: 3,
    image: '1181',
  },
  {
    id: 182,
    type: 'building',
    description: 'Drive-in theater',
    size: 3,
    image: '1182',
  },
  {
    id: 183,
    type: 'building',
    description: 'Office tower',
    size: 3,
    image: '1183',
  },
  {
    id: 184,
    type: 'building',
    description: 'Office tower',
    size: 3,
    image: '1184',
  },
  {
    id: 185,
    type: 'building',
    description: 'Parking lot',
    size: 3,
    image: '1185',
  },
  {
    id: 186,
    type: 'building',
    description: 'Historic office building',
    size: 3,
    image: '1186',
  },
  {
    id: 187,
    type: 'building',
    description: 'Corporate headquarters',
    size: 3,
    image: '1187',
  },
  {
    id: 188,
    type: 'building',
    description: 'Chemical processing',
    size: 3,
    image: '1188',
  },
  {
    id: 189,
    type: 'building',
    description: 'Large factory',
    size: 3,
    image: '1189',
  },
  {
    id: 190,
    type: 'building',
    description: 'Industrial thingamajig',
    size: 3,
    image: '1190',
  },
  {
    id: 191,
    type: 'building',
    description: 'Factory',
    size: 3,
    image: '1191',
  },
  {
    id: 192,
    type: 'building',
    description: 'Large warehouse',
    size: 3,
    image: '1192',
  },
  {
    id: 193,
    type: 'building',
    description: 'Warehouse',
    size: 3,
    image: '1193',
  },
  {
    id: 194,
    type: 'building',
    description: 'Construction',
    size: 3,
    image: '1194',
  },
  {
    id: 195,
    type: 'building',
    description: 'Construction',
    size: 3,
    image: '1195',
  },
  {
    id: 196,
    type: 'building',
    description: 'Abandoned building',
    size: 3,
    image: '1196',
  },
  {
    id: 197,
    type: 'building',
    description: 'Abandoned building',
    size: 3,
    image: '1197',
  },
  {
    id: 198,
    type: 'building',
    subtype: 'water',
    description: 'Hydroelectric power',
    size: 1,
    image: '1198',
    rotate: [198, 199, 198, 199],
    flip: true,
    flipMode: 'alternateTile',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Hydro Generators', type: 'hydroGeneratorCount' },
      data3: { description: 'Max System Output', type: 'hydroGeneratorMegawatts' },
      data4: { description: null, type: null },
    }
  },
  {
    id: 199,
    type: 'building',
    subtype: 'water',
    description: 'Hydroelectric power',
    size: 1,
    image: '1199',
    rotate: [199, 198, 199, 198],
    flip: true,
    flipMode: 'alternateTile',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Hydro Generators', type: 'hydroGeneratorCount' },
      data3: { description: 'Max System Output', type: 'hydroGeneratorMegawatts' },
      data4: { description: null, type: null },
    }
  },
  {
    id: 200,
    type: 'building',
    description: 'Wind power',
    size: 1,
    image: '1200',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Wind Generators', type: 'windGeneratorCount' },
      data3: { description: 'Max System Output', type: 'windGeneratorMegawatts' },
      data4: { description: null, type: null },
    }
  },
  {
    id: 201,
    type: 'building',
    description: 'Natural gas power plant',
    size: 4,
    image: '1201',
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 202,
    type: 'building',
    description: 'Oil power plant',
    size: 4,
    image: '1202',
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 203,
    type: 'building',
    description: 'Nuclear power plant',
    size: 4,
    image: '1203',
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 204,
    type: 'building',
    description: 'Solar power plant',
    size: 4,
    image: '1204',
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 205,
    type: 'building',
    description: 'Microwave power receiver',
    size: 4,
    image: '1205',
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 206,
    type: 'building',
    description: 'Fusion power plant',
    size: 4,
    image: '1206',
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 207,
    type: 'building',
    description: 'Coal power plant',
    size: 4,
    image: '1207',
    frameRate: 4,
    microsimulator: {
      data1: { description: 'Age', type: 'years', max: 50 },
      data2: { description: 'Max Output', type: 'megawatts' },
      data3: { description: 'Current Load', type: 'capacity', max: 100 },
      data4: { description: null, type: null },
    }
  },
  {
    id: 208,
    type: 'building',
    description: 'City hall',
    size: 3,
    image: '1208',
    microsimulator: {
      data1: { description: null, type: null },
      data2: { description: 'Employees', type: 'workers' },
      data3: { description: 'Year Built', type: 'constructionYear' },
      data4: { description: null, type: null },
      // unknowns: weddings and bungee jumps report the same count?
    }
  },
  {
    id: 209,
    type: 'building',
    description: 'Hospital',
    size: 3,
    image: '1209',
    microsimulator: {
      data1: { description: 'Grade', type: 'grade' }, // A+ = 12?
      data2: { description: 'Patients', type: 'hospitalPatients', max: 1000 },
      data3: { description: 'Doctors', type: 'workers' },
      data4: { description: 'Annual Cost', type: 'funds' },
      // unknown: beds = 1000
    }
  },
  {
    id: 210,
    type: 'building',
    description: 'Police station',
    size: 3,
    image: '1210',
    microsimulator: {
      data1: { description: 'Annual Cost', type: 'funds' },
      data2: { description: 'Officers', type: 'workers' },
      data3: { description: 'Crimes Reported', type: 'crimes' },
      data4: { description: 'Arrests', type: 'arrests' },
    }
  },
  {
    id: 211,
    type: 'building',
    description: 'Fire station',
    size: 3,
    image: '1211',
    microsimulator: {
      data1: { description: 'Annual Cost', type: 'funds' },
      data2: { description: 'Firefighers', type: 'workers' },
      data3: { description: 'Fire Engines', type: 'fireEquipment' },
      data4: { description: 'Response Time', type: 'fireResponseTime' },
    }
  },
  {
    id: 212,
    type: 'building',
    description: 'Museum',
    size: 3,
    image: '1212',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Attendance', type: 'museumAttendance' },
      data3: { description: 'Exhibits', type: 'museumExhibits' },
      data4: { description: null, type: null },
    }
  },
  {
    id: 213,
    type: 'building',
    description: 'Park (big)',
    size: 3,
    image: '1213',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Attendance', type: 'parkAttendance' },
      data3: { description: 'Acres', type: 'parkAcres' },
      data4: { description: 'Employees', type: 'parkWorkers' },
      // unknowns: Capacity is reported as 1500
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 214,
    type: 'building',
    description: 'School',
    size: 3,
    image: '1214',
    microsimulator: {
      data1: { description: 'Grade', type: 'grade' }, // A+ = 12?
      data2: { description: 'Students', type: 'students', max: 1500 },
      data3: { description: 'Teachers', type: 'workers' },
      data4: { description: 'Annual Cost', type: 'funds' },
      // unknowns: Capacity is reported as 1500
    }
  },
  {
    id: 215,
    type: 'building',
    description: 'Stadium',
    size: 4,
    image: '1215',
    microsimulator: {
      data1: { description: 'Wins', type: 'stadiumWins' },
      data2: { description: 'Attendance', type: 'stadiumAttendance', max: 25000 },
      data3: { description: null, type: null },
      data4: { description: null, type: null },
      // unknowns: Capacity is reported as 25000
      // loses are reported with wins
      // data3: team type reference? 1 == baseball
      // data4: team name reference?
    }
  },
  {
    id: 216,
    type: 'building',
    description: 'Prison',
    size: 4,
    image: '1216',
    microsimulator: {
      data1: { description: 'Escapes', type: 'prisonEscapes' },
      data2: { description: 'Inmates', type: 'prisonInmates', max: 10000 },
      data3: { description: 'Guards', type: 'workers' },
      data4: { description: 'Capacity', type: 'capacity', max: 100 },
      // unknown: max inames is reported as 10000
    }
  },
  {
    id: 217,
    type: 'building',
    description: 'College',
    size: 4,
    image: '1217',
    microsimulator: {
      data1: { description: 'Grade', type: 'grade' }, // 6 = C+ ?, 10 = A-
      data2: { description: 'Attendance', type: 'students', max: 5000 },
      data3: { description: 'Teachers', type: 'workers' },
      data4: { description: 'Annual Cost', type: 'funds' },
      // unknowns: Capacity is reported as 1500
    }
  },
  {
    id: 218,
    type: 'building',
    description: 'Zoo',
    size: 4,
    image: '1218',
    microsimulator: {
      data1: { description: 'Other Dromedaries', type: 'zooOther' },
      data2: { description: 'Peruvian Llamas', type: 'zooLlamasP' },
      data3: { description: 'Andean Llamas', type: 'zooLlamasA' },
      data4: { description: 'Alpacas', type: 'zooAlpacas' },
      // unknowns: Capacity is reported as 1500
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 219,
    type: 'building',
    description: 'Statue',
    size: 1,
    image: '1219',
    microsimulator: {
      data1: { description: null, type: null },
      data2: { description: 'Year Built', type: 'constructionYear' },
      data3: { description: 'Pigeons Perched', type: 'statuePigeons' },
      data4: { description: null, type: null },
      // unknown: Material: Bronze
      // unknown: Height - reports cell Z level in feet?
    }
  },
  {
    id: 220,
    type: 'building',
    description: 'Water pump',
    size: 1,
    image: '1220',
  },
  {
    id: 221,
    type: 'building',
    description: 'Runway (straight)',
    size: 1,
    image: '1221',
    flip: true,
  },
  {
    id: 222,
    type: 'building',
    description: 'Runway (intersection)',
    size: 1,
    image: '1222',
  },
  {
    id: 223,
    type: 'building',
    description: 'Pier',
    size: 1,
    image: '1223',
    logic: {
      create: 'pier'
    }
  },
  {
    id: 224,
    type: 'building',
    description: 'Crane',
    size: 1,
    image: '1224',
    logic: {
      create: 'pier'
    }
  },
  {
    id: 225,
    type: 'building',
    description: 'Control tower',
    size: 1,
    image: '1225',
  },
  {
    id: 226,
    type: 'building',
    description: 'Control tower',
    size: 1,
    image: '1226',
  },
  {
    id: 227,
    type: 'building',
    description: 'Seaport warehouse',
    size: 1,
    image: '1227',
  },
  {
    id: 228,
    type: 'building',
    description: 'Airport building',
    size: 1,
    image: '1228',
  },
  {
    id: 229,
    type: 'building',
    description: 'Airport building',
    size: 1,
    image: '1229',
  },
  {
    id: 230,
    type: 'building',
    description: 'Tarmac',
    size: 1,
    image: '1230',
  },
  {
    id: 231,
    type: 'building',
    description: 'F-15b',
    size: 1,
    image: '1231',
  },
  {
    id: 232,
    type: 'building',
    description: 'Hangar',
    size: 1,
    image: '1232',
  },
  {
    id: 233,
    type: 'building',
    subtype: 'subway',
    description: 'Subway station',
    size: 1,
    image: '1233',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Subway Stations', type: 'subwayStationCount' },
      data3: { description: null, type: null },
      data4: { description: 'Passengers / day', type: 'subwayStationPassengers' },
      // unknown: data1?
      // two entries in a city for 236
    }
  },
  {
    id: 234,
    type: 'building',
    description: 'Radar',
    size: 1,
    image: '1234',
  },
  {
    id: 235,
    type: 'building',
    description: 'Water tower',
    size: 2,
    image: '1235',
  },
  {
    id: 236,
    type: 'building',
    description: 'Bus station',
    size: 2,
    image: '1236',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Bus Stations', type: 'busStationCount' },
      data3: { description: 'Buses', type: 'busStationBuses' },
      data4: { description: 'Passengers / day', type: 'busStationPassengers' },
      // unknown: data1?
      // two entries in a city for 236
    }
  },
  {
    id: 237,
    type: 'building',
    description: 'Rail station',
    size: 2,
    image: '1237',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Rail Stations', type: 'railStationCount' },
      data3: { description: null, type: null },
      data4: { description: 'Passengers / day', type: 'railStationPassengers' },
      // unknown: data1?
      // two entries in a city for 236
    }
  },
  {
    id: 238,
    type: 'building',
    description: 'Parking lot',
    size: 2,
    image: '1238',
  },
  {
    id: 239,
    type: 'building',
    description: 'Parking lot',
    size: 2,
    image: '1239',
  },
  {
    id: 240,
    type: 'building',
    description: 'Loading bay',
    size: 2,
    image: '1240',
  },
  {
    id: 241,
    type: 'building',
    description: 'Top secret',
    size: 2,
    image: '1241',
  },
  {
    id: 242,
    type: 'building',
    description: 'Cargo yard',
    size: 2,
    image: '1242',
  },
  {
    id: 243,
    type: 'building',
    description: 'Mayor\'s house',
    size: 2,
    image: '1243',
    microsimulator: {
      data1: { description: 'Door Steps', type: 'mayorDoorSteps' },
      data2: { description: 'Year Built', type: 'constructionYear' },
      data3: { description: 'Approval Rating', type: 'mayorApprovalRating', max: 100 },
      data4: { description: 'Employees', type: 'workers' },
    }
  },
  {
    id: 244,
    type: 'building',
    description: 'Water treatment plant',
    size: 2,
    image: '1244',
    microsimulator: {
      data1: { description: null, type: null },
      data2: { description: 'Untreated Water', type: 'waterCubicFeet', unit: 'thousands' },
      data3: { description: 'Treated Water', type: 'waterCubicFeet', unit: 'thousands' },
      data4: { description: null, type: null },
      // capacity reported as 5000 cubic feet / minute, stored in data1?
      // example values: data1: 88, data2: 21, data3: 141
      // game shows: capacity 5000, untreated: 21000, treated: 141000
    }
  },
  {
    id: 245,
    type: 'building',
    description: 'Library',
    size: 2,
    image: '1245',
    microsimulator: {
      type: 'cityWide',
      data1: { description: 'Grade', type: 'grade' }, // 7 = B-
      data2: { description: 'Attendance', type: 'libraryAttendance' },
      data3: { description: 'Books', type: 'libraryBooks' },
      data4: { description: null, type: null },
    }
  },
  {
    id: 246,
    type: 'building',
    description: 'Hangar',
    size: 2,
    image: '1246',
  },
  {
    id: 247,
    type: 'building',
    description: 'Church',
    size: 2,
    image: '1247',
  },
  {
    id: 248,
    type: 'building',
    description: 'Marina',
    size: 3,
    image: '1248',
    microsimulator: {
      type: 'cityWide',
      data1: { description: null, type: null },
      data2: { description: 'Boats', type: 'marinaBoats' },
      data3: { description: null, type: null },
      data4: { description: null, type: null },
    }
  },
  {
    id: 249,
    type: 'building',
    description: 'Missile silo',
    size: 3,
    image: '1249',
  },
  {
    id: 250,
    type: 'building',
    description: 'Desalination plant',
    size: 3,
    image: '1250',
    microsimulator: {
      data1: { description: 'Current Load', type: 'capacity', max: 100 },
      data2: { description: 'Salt / tons Removed', type: 'desalinationSaltRemoved' },
      data3: { description: 'Employees', type: 'workers' },
      data4: { description: null, type: null },
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 251,
    type: 'building',
    description: 'Plymouth arcology',
    size: 4,
    image: '1251',
    microsimulator: {
      data1: { description: 'Condition', type: 'grade' }, //5 = C
      data2: { description: 'Design Capacity', type: 'arcoCapacity', unit: 'thousands' },
      data3: { description: 'Residents', type: 'arcoPopulation' },
      data4: { description: 'Year Built', type: 'constructionYear' },
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 252,
    type: 'building',
    description: 'Forest arcology',
    size: 4,
    image: '1252',
    microsimulator: {
      data1: { description: 'Condition', type: 'grade' }, //5 = C
      data2: { description: 'Design Capacity', type: 'arcoCapacity', unit: 'thousands' },
      data3: { description: 'Residents', type: 'arcoPopulation' },
      data4: { description: 'Year Built', type: 'constructionYear' },
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 253,
    type: 'building',
    description: 'Darco arcology',
    size: 4,
    image: '1253',
    microsimulator: {
      data1: { description: 'Condition', type: 'grade' }, //5 = C
      data2: { description: 'Design Capacity', type: 'arcoCapacity', unit: 'thousands' },
      data3: { description: 'Residents', type: 'arcoPopulation' },
      data4: { description: 'Year Built', type: 'constructionYear' },
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 254,
    type: 'building',
    description: 'Launch arcology',
    size: 4,
    image: '1254',
    microsimulator: {
      data1: { description: 'Condition', type: 'grade' }, //5 = C
      data2: { description: 'Design Capacity', type: 'arcoCapacity', unit: 'thousands' },
      data3: { description: 'Residents', type: 'arcoPopulation' },
      data4: { description: 'Year Built', type: 'constructionYear' },
    },
    importOptions: {
      frameCount: 1
    }
  },
  {
    id: 255,
    type: 'building',
    description: 'Braun Llama-dome',
    size: 4,
    image: '1255',
    microsimulator: {
      data1: { description: 'Weddings', type: 'domeWeddings' },
      data2: { description: 'Visitors', type: 'domeVisitors' },
      data3: { description: 'Llama Sightings', type: 'domeLlamaSightings' },
      data4: { description: 'Complaints', type: 'domeComplaints' },
      data5: { reference: 'data1', description: 'Bungee Jumps', type: 'domeBungeeJumps' },
      // unknowns: weddings and bungee jumps report the same count?
    }
  },
  {
    id: 256,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1256',
    heightmap: {
      lower: [
        { x: 16,  y: 0  },
        { x: 32,  y: 8  },
        { x: 16,  y: 16 },
        { x: 0,   y: 8  },
      ],
    }
  },
  {
    id: 257,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1257',
    heightmap: {
      southEast: [
        { x: 16,   y: 0  },
        { x: 32,   y: 20 },
        { x: 16,   y: 28 },
        { x: 0,    y: 8  },
      ],
      rockSouthWest: [
        { x: 16,   y: 28 },
        { x: 0,    y: 8 },
        { x: 0,    y: 20 },
      ],
    },
    rotate: [257, 258, 259, 260],
  },
  {
    id: 258,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1258',
    heightmap: {
      southWest: [
        { x: 16,   y: 0  },
        { x: 0,    y: 20 },
        { x: 16,   y: 28 },
        { x: 32,   y: 8  },
      ],
      rockSouthEast: [
        { x: 16,   y: 28 },
        { x: 32,   y: 8  },
        { x: 32,   y: 20 },
      ],
    },
    rotate: [258, 259, 260, 257],
  },
  {
    id: 259,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1259',
    heightmap: {
      northEast: [
        { x: 16,  y: 4  },
        { x: 32,  y: 0  },
        { x: 16,  y: 8  },
        { x: 0,   y: 12 },
      ],
      rockSouthWest: [
        { x: 16,  y: 8  },
        { x: 16,  y: 20 },
        { x: 0,   y: 12 },
      ],
      rockSouthEast: [
        { x: 16,  y: 8  },
        { x: 32,  y: 0  },
        { x: 32,  y: 12 },
        { x: 16,  y: 20 },
      ],
    },
    rotate: [259, 260, 257, 258],
  },
  {
    id: 260,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1260',
    heightmap: {
      northEast: [
        { x: 16,  y: 4  },
        { x: 32,  y: 12 },
        { x: 16,  y: 8  },
        { x: 0,   y: 0  },
      ],
      rockSouthWest: [
        { x: 0,   y: 0  },
        { x: 16,  y: 8  },
        { x: 16,  y: 20 },
        { x: 0,   y: 12 },
      ],
      rockSouthEast: [
        { x: 16,  y: 8  },
        { x: 32,  y: 12 },
        { x: 16,  y: 20 },
      ],
    },
    rotate: [260, 257, 258, 259],
  },
  {
    id: 261,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1261',
    heightmap: {
      upper: [
        { x: 0,   y: 8  },
        { x: 16,  y: 0  },
        { x: 32,  y: 8  },
      ],
      south: [
        { x: 0,   y: 8  },
        { x: 16,  y: 28 },
        { x: 32,  y: 8  },
      ],
      rockSouthWest: [
        { x: 0,   y: 8  },
        { x: 16,  y: 28 },
        { x: 0,   y: 20 },
      ],
      rockSouthEast: [
        { x: 32,  y: 8  },
        { x: 16,  y: 28 },
        { x: 32,  y: 20 },
      ],
    },
    rotate: [261, 262, 263, 264],
  },
  {
    id: 262,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1262',
    heightmap: {
      upper: [
        { x: 16,  y: 0  },
        { x: 32,  y: 8  },
        { x: 16,  y: 16 },
      ],
      west: [
        { x: 16,  y: 0  },
        { x: 16,  y: 16 },
        { x: 0,   y: 20 },
      ],
      rockSouthWest: [
        { x: 16,  y: 28 },
        { x: 16,  y: 16 },
        { x: 0,   y: 20 },
      ],
      rockSouthEast: [
        { x: 32,  y: 8  },
        { x: 32,  y: 20 },
        { x: 16,  y: 28 },
        { x: 16,  y: 16 },
      ],
    },
    rotate: [262, 263, 264, 261],
  },
  {
    id: 263,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1263',
    heightmap: {
      upper: [
        { x: 0,    y: 0  },
        { x: 32,   y: 0  },
        { x: 16,   y: 8  },
      ],
      rockSouthWest: [
        { x: 0,    y: 0  },
        { x: 16,   y: 8  },
        { x: 16,   y: 20 },
        { x: 0,    y: 12 },
      ],
      rockSouthEast: [
        { x: 32,   y: 0  },
        { x: 16,   y: 8  },
        { x: 16,   y: 20 },
        { x: 32,   y: 12 },
      ],
    },
    rotate: [263, 264, 261, 262],
  },
  {
    id: 264,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1264',
    heightmap: {
      upper: [
        { x: 0,    y: 8  },
        { x: 16,   y: 0  },
        { x: 16,   y: 16 },
      ],
      east: [
        { x: 16,   y: 0  },
        { x: 32,   y: 20 },
        { x: 16,   y: 16 },
      ],
      rockSouthWest: [
        { x: 16,   y: 16 },
        { x: 0,    y: 8  },
        { x: 0,    y: 20 },
        { x: 16,   y: 28 },
      ],
      rockSouthEast: [
        { x: 16,   y: 16 },
        { x: 32,   y: 20 },
        { x: 16,   y: 28 },
      ],
    },
    rotate: [264, 261, 262, 263],
  },
  {
    id: 265,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1265',
    heightmap: {
      lower: [
        { x: 0,    y: 20 },
        { x: 32,   y: 20 },
        { x: 16,   y: 28 },
      ],
      south: [
        { x: 0,    y: 20 },
        { x: 32,   y: 20 },
        { x: 16,   y: 0 },
      ],
    },
    rotate: [265, 266, 267, 268],
  },
  {
    id: 266,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1266',
    heightmap: {
      lower: [
        { x: 0,    y: 12 },
        { x: 16,   y: 4  },
        { x: 16,   y: 20 },
      ],
      west: [
        { x: 16,   y: 4  },
        { x: 32,   y: 0  },
        { x: 16,   y: 20 },
      ],
      rockSouthEast: [
        { x: 32,   y: 0  },
        { x: 16,   y: 20 },
        { x: 32,   y: 12 },
      ],
    },
    rotate: [266, 267, 268, 265],
  },
  {
    id: 267,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1267',
    heightmap: {
      lower: [
        { x: 0,    y: 8  },
        { x: 16,   y: 0  },
        { x: 32,   y: 8  },
        { x: 16,   y: 4  },
      ],
      rockSouthWest: [
        { x: 16,   y: 4  },
        { x: 32,   y: 8  },
        { x: 16,   y: 16 },
      ],
      rockSouthEast: [
        { x: 16,   y: 4  },
        { x: 0,    y: 8  },
        { x: 16,   y: 16 },
      ],
    },
    rotate: [267, 268, 265, 266],
  },
  {
    id: 268,
    type: 'terrain',
    description: 'land',
    size: 1,
    image: '1268',
    heightmap: {
      lower: [
        { x: 32,   y: 12 },
        { x: 16,   y: 4  },
        { x: 16,   y: 20 },
      ],
      east: [
        { x: 16,   y: 4  },
        { x: 0,    y: 0  },
        { x: 16,   y: 20 },
      ],
      rockSouthWest: [
        { x: 0,    y: 0  },
        { x: 16,   y: 20 },
        { x: 0,    y: 12 },
      ],
    },
    rotate: [268, 265, 266, 267],
  },
  {
    id: 269,
    type: 'terrain',
    description: 'rock',
    size: 1,
    image: '1269',
    heightmap: {
      upper: [
        { x: 16,  y: 0 },
        { x: 32,  y: 8  },
        { x: 16,  y: 16 },
        { x: 0,   y: 8  },
      ],
      rockSouthWest: [
        { x: 32,  y: 8  },
        { x: 32,  y: 20 },
        { x: 16,  y: 28 },
        { x: 16,  y: 16 },
      ],
      rockSouthEast: [
        { x: 0,   y: 8  },
        { x: 16,  y: 16 },
        { x: 16,  y: 28 },
        { x: 0,   y: 20 },
      ],
    },
  },
  {
    id: 270,
    type: 'water',
    description: 'water_tile_1',
    size: 1,
    image: '1270',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    frames: 2,
  },
  {
    id: 271,
    type: 'water',
    description: 'water_tile_2',
    size: 1,
    image: '1271',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 257
    },
    rotate: [271, 272, 273, 274],
    frames: 2,
  },
  {
    id: 272,
    type: 'water',
    description: 'water_tile_3',
    size: 1,
    image: '1272',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 258
    },
    rotate: [272, 273, 274, 271],
    frames: 2,
  },
  {
    id: 273,
    type: 'water',
    description: 'water_tile_4',
    size: 1,
    image: '1273',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 259
    },
    rotate: [273, 274, 271, 272],
    frames: 2,
  },
  {
    id: 274,
    type: 'water',
    description: 'water_tile_5',
    size: 1,
    image: '1274',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 260
    },
    rotate: [274, 271, 272, 273],
    frames: 2,
  },
  {
    id: 275,
    type: 'water',
    description: 'water_tile_6',
    size: 1,
    image: '1275',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 261
    },
    rotate: [275, 276, 277, 278],
    frames: 2,
  },
  {
    id: 276,
    type: 'water',
    description: 'water_tile_7',
    size: 1,
    image: '1276',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 262
    },
    rotate: [276, 277, 278, 275],
    frames: 2,
  },
  {
    id: 277,
    type: 'water',
    description: 'water_tile_8',
    size: 1,
    image: '1277',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 263
    },
    rotate: [277, 278, 275, 276],
    frames: 2,
  },
  {
    id: 278,
    type: 'water',
    description: 'water_tile_9',
    size: 1,
    image: '1278',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 264
    },
    rotate: [278, 275, 276, 277],
    frames: 2,
  },
  {
    id: 279,
    type: 'water',
    description: 'water_tile_10',
    size: 1,
    image: '1279',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 265
    },
    rotate: [279, 280, 281, 282],
    frames: 2,
  },
  {
    id: 280,
    type: 'water',
    description: 'water_tile_11',
    size: 1,
    image: '1280',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 266
    },
    rotate: [280, 281, 282, 279],
    frames: 2,
  },
  {
    id: 281,
    type: 'water',
    description: 'water_tile_12',
    size: 1,
    image: '1281',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 267
    },
    rotate: [281, 282, 279, 280],
    frames: 2,
  },
  {
    id: 282,
    type: 'water',
    description: 'water_tile_13',
    size: 1,
    image: '1282',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 268
    },
    rotate: [282, 279, 280, 281],
    frames: 2,
  },
  {
    id: 283,
    type: 'water',
    description: 'water_tile_14',
    size: 1,
    image: '1283',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 269
    },
    frames: 2,
  },
  {
    id: 284,
    type: 'water',
    description: 'waterfall',
    size: 1,
    image: '1284',
    hitbox: {
      reference: 269
    },
    heightmap: {
      reference: 269
    },
    frames: 3,
  },
  {
    id: 285,
    type: 'water',
    description: 'water_tile_15',
    size: 1,
    image: '1285',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    rotate: [285, 286, 285, 286],
    frames: 2,
  },
  {
    id: 286,
    type: 'water',
    description: 'water_tile_16',
    size: 1,
    image: '1286',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    rotate: [286, 285, 286, 285],
    frames: 2,
  },
  {
    id: 287,
    type: 'water',
    description: 'water_tile_17',
    size: 1,
    image: '1287',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    rotate: [287, 288, 289, 290],
    frames: 2,
  },
  {
    id: 288,
    type: 'water',
    description: 'water_tile_18',
    size: 1,
    image: '1288',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    rotate: [288, 289, 290, 287],
    frames: 2,
  },
  {
    id: 289,
    type: 'water',
    description: 'water_tile_19',
    size: 1,
    image: '1289',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    rotate: [289, 290, 287, 288],
    frames: 2,
  },
  {
    id: 290,
    type: 'water',
    description: 'water_tile_20',
    size: 1,
    image: '1290',
    hitbox: {
      reference: 256
    },
    heightmap: {
      reference: 256
    },
    rotate: [290, 287, 288, 289],
    frames: 2,
  },
  {
    id: 291,
    type: 'zone',
    description: 'Low Density Residential Zone',
    size: 1,
    image: '1291',
  },
  {
    id: 292,
    type: 'zone',
    description: 'High Density Residential Zone',
    size: 1,
    image: '1292',
  },
  {
    id: 293,
    type: 'zone',
    description: 'Low Density Commercial Zone',
    size: 1,
    image: '1293',
  },
  {
    id: 294,
    type: 'zone',
    description: 'High Density Commercial Zone',
    size: 1,
    image: '1294',
  },
  {
    id: 295,
    type: 'zone',
    description: 'Low Density Industrial Zone',
    size: 1,
    image: '1295',
  },
  {
    id: 296,
    type: 'zone',
    description: 'High Density Industrial Zone',
    size: 1,
    image: '1296',
  },
  {
    id: 297,
    type: 'zone',
    description: 'Military Zone',
    size: 1,
    image: '1297',
  },
  {
    id: 298,
    type: 'zone',
    description: 'Airport Zone',
    size: 1,
    image: '1298',
  },
  {
    id: 299,
    type: 'zone',
    description: 'Seaport Zone',
    size: 1,
    image: '1299',
  },
  {
    id: 300,
    type: 'overlay',
    description: 'green_tile',
    size: 1,
    image: '1300',
  },
  {
    id: 301,
    type: 'overlay',
    description: 'blue_tile',
    size: 1,
    image: '1301',
  },
  {
    id: 302,
    type: 'overlay',
    description: 'yellow_tile',
    size: 1,
    image: '1302',
  },
  {
    id: 303,
    type: 'overlay',
    description: 'red_tile',
    size: 1,
    image: '1303',
  },
  {
    id: 304,
    type: 'overlay',
    description: 'grey_tile',
    size: 1,
    image: '1304',
  },
  {
    id: 305,
    type: 'underground',
    description: 'underground_land_1',
    size: 1,
    image: '1305',
  },
  {
    id: 306,
    type: 'underground',
    description: 'underground_land_2',
    size: 1,
    image: '1306',
  },
  {
    id: 307,
    type: 'underground',
    description: 'underground_land_3',
    size: 1,
    image: '1307',
  },
  {
    id: 308,
    type: 'underground',
    description: 'underground_land_4',
    size: 1,
    image: '1308',
  },
  {
    id: 309,
    type: 'underground',
    description: 'underground_land_5',
    size: 1,
    image: '1309',
  },
  {
    id: 310,
    type: 'underground',
    description: 'underground_land_6',
    size: 1,
    image: '1310',
  },
  {
    id: 311,
    type: 'underground',
    description: 'underground_land_7',
    size: 1,
    image: '1311',
  },
  {
    id: 312,
    type: 'underground',
    description: 'underground_land_8',
    size: 1,
    image: '1312',
  },
  {
    id: 313,
    type: 'underground',
    description: 'underground_land_9',
    size: 1,
    image: '1313',
  },
  {
    id: 314,
    type: 'underground',
    description: 'underground_land_10',
    size: 1,
    image: '1314',
  },
  {
    id: 315,
    type: 'underground',
    description: 'underground_land_11',
    size: 1,
    image: '1315',
  },
  {
    id: 316,
    type: 'underground',
    description: 'underground_land_12',
    size: 1,
    image: '1316',
  },
  {
    id: 317,
    type: 'underground',
    description: 'underground_land_13',
    size: 1,
    image: '1317',
  },
  {
    id: 318,
    type: 'underground',
    description: 'underground_land_14',
    size: 1,
    image: '1318',
  },
  {
    id: 319,
    type: 'subway',
    description: 'Subway (straight)',
    size: 1,
    image: '1319',
  },
  {
    id: 320,
    type: 'subway',
    description: 'Subway (straight)',
    size: 1,
    image: '1320',
  },
  {
    id: 321,
    type: 'subway',
    description: 'Subway (slope)',
    size: 1,
    image: '1321',
    rotate: [321, 322, 323, 324],
  },
  {
    id: 322,
    type: 'subway',
    description: 'Subway (slope)',
    size: 1,
    image: '1322',
    rotate: [322, 323, 324, 321],
  },
  {
    id: 323,
    type: 'subway',
    description: 'Subway (slope)',
    size: 1,
    image: '1323',
    rotate: [327, 328, 325, 326],
  },
  {
    id: 324,
    type: 'subway',
    description: 'Subway (slope)',
    size: 1,
    image: '1324',
    rotate: [328, 325, 326, 327],
  },
  {
    id: 325,
    type: 'subway',
    description: 'Subway (corner)',
    size: 1,
    image: '1325',
    rotate: [325, 326, 327, 328],
  },
  {
    id: 326,
    type: 'subway',
    description: 'Subway (corner)',
    size: 1,
    image: '1326',
    rotate: [326, 327, 328, 325],
  },
  {
    id: 327,
    type: 'subway',
    description: 'Subway (corner)',
    size: 1,
    image: '1327',
    rotate: [327, 328, 325, 326],
  },
  {
    id: 328,
    type: 'subway',
    description: 'Subway (corner)',
    size: 1,
    image: '1328',
    rotate: [328, 325, 326, 327],
  },
  {
    id: 329,
    type: 'subway',
    description: 'Subway (intersection)',
    size: 1,
    image: '1329',
  },
  {
    id: 330,
    type: 'subway',
    description: 'Subway (intersection)',
    size: 1,
    image: '1330',
  },
  {
    id: 331,
    type: 'subway',
    description: 'Subway (intersection)',
    size: 1,
    image: '1331',
  },
  {
    id: 332,
    type: 'subway',
    description: 'Subway (intersection)',
    size: 1,
    image: '1332',
  },
  {
    id: 333,
    type: 'subway',
    description: 'Subway (intersection)',
    size: 1,
    image: '1333',
  },
  {
    id: 334,
    type: 'pipe',
    description: 'water_pipe_1',
    size: 1,
    image: '1334',
  },
  {
    id: 335,
    type: 'pipe',
    description: 'water_pipe_2',
    size: 1,
    image: '1335',
  },
  {
    id: 336,
    type: 'pipe',
    description: 'water_pipe_3',
    size: 1,
    image: '1336',
  },
  {
    id: 337,
    type: 'pipe',
    description: 'water_pipe_4',
    size: 1,
    image: '1337',
  },
  {
    id: 338,
    type: 'pipe',
    description: 'water_pipe_5',
    size: 1,
    image: '1338',
  },
  {
    id: 339,
    type: 'pipe',
    description: 'water_pipe_6',
    size: 1,
    image: '1339',
  },
  {
    id: 340,
    type: 'pipe',
    description: 'water_pipe_7',
    size: 1,
    image: '1340',
  },
  {
    id: 341,
    type: 'pipe',
    description: 'water_pipe_8',
    size: 1,
    image: '1341',
  },
  {
    id: 342,
    type: 'pipe',
    description: 'water_pipe_9',
    size: 1,
    image: '1342',
  },
  {
    id: 343,
    type: 'pipe',
    description: 'water_pipe_10',
    size: 1,
    image: '1343',
  },
  {
    id: 344,
    type: 'pipe',
    description: 'water_pipe_11',
    size: 1,
    image: '1344',
  },
  {
    id: 345,
    type: 'pipe',
    description: 'water_pipe_12',
    size: 1,
    image: '1345',
  },
  {
    id: 346,
    type: 'pipe',
    description: 'water_pipe_13',
    size: 1,
    image: '1346',
  },
  {
    id: 347,
    type: 'pipe',
    description: 'water_pipe_14',
    size: 1,
    image: '1347',
  },
  {
    id: 348,
    type: 'pipe',
    description: 'water_pipe_15',
    size: 1,
    image: '1348',
  },
  {
    id: 349,
    type: 'subway',
    subtype: 'pipe',
    description: 'Subway (straight) with Pipe',
    size: 1,
    image: '1349',
  },
  {
    id: 350,
    type: 'subway',
    subtype: 'pipe',
    description: 'Subway (straight) with Pipe',
    size: 1,
    image: '1350',
  },
  {
    id: 351,
    type: 'pipe',
    description: 'Building Pipes',
    size: 1,
    image: '1351',
  },
  {
    id: 352,
    type: 'overlay',
    description: 'grey_box_1',
    size: 1,
    image: '1352',
  },
  {
    id: 353,
    type: 'overlay',
    description: 'grey_box_2',
    size: 1,
    image: '1353',
  },
  {
    id: 354,
    type: 'overlay',
    description: 'green_outline',
    size: 1,
    image: '1354',
  },
  {
    id: 355,
    type: 'overlay',
    description: 'blue_outline',
    size: 1,
    image: '1355',
  },
  {
    id: 356,
    type: 'overlay',
    description: 'brown_outline',
    size: 1,
    image: '1356',
  },
  {
    id: 357,
    type: 'overlay',
    description: 'red_outline',
    size: 1,
    image: '1357',
  },
  {
    id: 358,
    type: 'overlay',
    description: 'grey_outline',
    size: 1,
    image: '1358',
  },
  {
    id: 359,
    type: 'actor',
    description: 'airplane_1',
    size: 2,
    image: '1359',
  },
  {
    id: 360,
    type: 'actor',
    description: 'airplane_2',
    size: 2,
    image: '1360',
  },
  {
    id: 361,
    type: 'actor',
    description: 'airplane_3',
    size: 2,
    image: '1361',
  },
  {
    id: 362,
    type: 'actor',
    description: 'airplane_4',
    size: 2,
    image: '1362',
  },
  {
    id: 363,
    type: 'actor',
    description: 'airplane_5',
    size: 2,
    image: '1363',
  },
  {
    id: 364,
    type: 'actor',
    description: 'sim_copter_1',
    size: 1,
    image: '1364',
  },
  {
    id: 365,
    type: 'actor',
    description: 'sim_copter_2',
    size: 1,
    image: '1365',
  },
  {
    id: 366,
    type: 'actor',
    description: 'sim_copter_3',
    size: 1,
    image: '1366',
  },
  {
    id: 367,
    type: 'actor',
    description: 'sim_copter_4',
    size: 1,
    image: '1367',
  },
  {
    id: 368,
    type: 'actor',
    description: 'sim_copter_5',
    size: 1,
    image: '1368',
  },
  {
    id: 369,
    type: 'actor',
    description: 'cargo_ship_1',
    size: 2,
    image: '1369',
  },
  {
    id: 370,
    type: 'actor',
    description: 'cargo_ship_2',
    size: 2,
    image: '1370',
  },
  {
    id: 371,
    type: 'actor',
    description: 'cargo_ship_3',
    size: 2,
    image: '1371',
  },
  {
    id: 372,
    type: 'actor',
    description: 'cargo_ship_4',
    size: 2,
    image: '1372',
  },
  {
    id: 373,
    type: 'actor',
    description: 'cargo_ship_5',
    size: 2,
    image: '1373',
  },
  {
    id: 374,
    type: 'actor',
    description: 'train_1',
    size: 1,
    image: '1374',
  },
  {
    id: 375,
    type: 'actor',
    description: 'train_2',
    size: 1,
    image: '1375',
  },
  {
    id: 376,
    type: 'actor',
    description: 'train_3',
    size: 1,
    image: '1376',
  },
  {
    id: 377,
    type: 'actor',
    description: 'train_4',
    size: 1,
    image: '1377',
  },
  {
    id: 378,
    type: 'actor',
    description: 'train_5',
    size: 1,
    image: '1378',
  },
  {
    id: 379,
    type: 'actor',
    description: 'nessie',
    size: 1,
    image: '1379',
  },
  {
    id: 380,
    type: 'actor',
    description: 'sail_boat_1',
    size: 1,
    image: '1380',
  },
  {
    id: 381,
    type: 'actor',
    description: 'sail_boat_2',
    size: 1,
    image: '1381',
  },
  {
    id: 382,
    type: 'sign',
    description: 'police_sign',
    size: 1,
    image: '1382',
  },
  {
    id: 383,
    type: 'sign',
    description: 'fire_dept_sign',
    size: 1,
    image: '1383',
  },
  {
    id: 384,
    type: 'sign',
    description: 'military_sign',
    size: 1,
    image: '1384',
  },
  {
    id: 385,
    type: 'monster',
    description: 'space_ray',
    size: 1,
    image: '1385',
  },
  {
    id: 386,
    type: 'overlay',
    description: 'power_outage_lightning',
    size: 1,
    image: '1386',
  },
  {
    id: 387,
    type: 'explosion',
    description: 'explosion_1',
    size: 2,
    image: '1387',
  },
  {
    id: 388,
    type: 'explosion',
    description: 'explosion_2',
    size: 2,
    image: '1388',
  },
  {
    id: 389,
    type: 'explosion',
    description: 'explosion_3',
    size: 2,
    image: '1389',
  },
  {
    id: 390,
    type: 'actor',
    description: 'bulldozer_1',
    size: 1,
    image: '1390',
  },
  {
    id: 391,
    type: 'actor',
    description: 'bulldozer_2',
    size: 1,
    image: '1391',
  },
  {
    id: 392,
    type: 'actor',
    description: 'dust_cloud_1',
    size: 1,
    image: '1392',
  },
  {
    id: 393,
    type: 'actor',
    description: 'dust_cloud_2',
    size: 1,
    image: '1393',
  },
  {
    id: 394,
    type: 'actor',
    description: 'dust_cloud_3',
    size: 1,
    image: '1394',
  },
  {
    id: 395,
    type: 'actor',
    description: 'dust_cloud_4',
    size: 1,
    image: '1395',
  },
  {
    id: 396,
    type: 'fire',
    description: 'fire_1',
    size: 1,
    image: '1396',
  },
  {
    id: 397,
    type: 'fire',
    description: 'fire_2',
    size: 1,
    image: '1397',
  },
  {
    id: 398,
    type: 'fire',
    description: 'fire_3',
    size: 1,
    image: '1398',
  },
  {
    id: 399,
    type: 'fire',
    description: 'fire_4',
    size: 1,
    image: '1399',
  },
  {
    id: 400,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (straight)',
    size: 1,
    image: '1400',
    rotate: [400, 401, 400, 401],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 401,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (straight)',
    size: 1,
    image: '1401',
    rotate: [401, 400, 401, 400],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 402,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (sloped)',
    size: 1,
    image: '1402',
    rotate: [402, 403, 404, 405],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 403,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (sloped)',
    size: 1,
    image: '1403',
    rotate: [403, 404, 405, 402],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 404,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (sloped)',
    size: 1,
    image: '1404',
    rotate: [404, 405, 402, 403],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 405,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (sloped)',
    size: 1,
    image: '1405',
    rotate: [405, 402, 403, 404],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 406,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (curve)',
    size: 1,
    image: '1406',
    rotate: [406, 407, 408, 409],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 407,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (curve)',
    size: 1,
    image: '1407',
    rotate: [407, 408, 409, 406],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 408,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (curve)',
    size: 1,
    image: '1408',
    rotate: [408, 409, 406, 407],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 409,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (curve)',
    size: 1,
    image: '1409',
    rotate: [409, 406, 407, 408],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 410,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Straight)',
    flip: true,
    size: 1,
    rotate: [410, 411, 410, 411],
    image: '1410',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 411,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Straight)',
    flip: true,
    size: 1,
    rotate: [411, 410, 411, 410],
    image: '1411',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 412,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'traffic_13',
    size: 1,
    image: '1412',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 413,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'traffic_14',
    size: 1,
    image: '1413',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 414,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Onramp)',
    size: 1,
    rotate: [414, 417, 414, 417],
    flip: true,
    flipMode: 'alternateTile',
    image: '1414',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 415,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Onramp)',
    size: 1,
    rotate: [415, 416, 415, 416],
    flip: true,
    flipMode: 'alternateTile',
    image: '1415',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 416,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Onramp)',
    size: 1,
    rotate: [416, 415, 416, 415],
    flip: true,
    flipMode: 'alternateTile',
    image: '1416',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 417,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Onramp)',
    size: 1,
    rotate: [417, 414, 417, 414],
    flip: true,
    flipMode: 'alternateTile',
    image: '1417',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 418,
    type: 'traffic',
    frameRate: 6,
    description: 'Light Traffic (Highway Slope)',
    size: 2,
    rotate: [418, 419, 420, 421],
    image: '1418',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 419,
    type: 'traffic',
    frameRate: 6,
    description: 'Light Traffic (Highway Slope)',
    size: 2,
    rotate: [419, 420, 421, 418],
    image: '1419',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 420,
    type: 'traffic',
    frameRate: 6,
    description: 'Light Traffic (Highway Slope)',
    size: 2,
    rotate: [420, 421, 418, 419],
    image: '1420',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 421,
    type: 'traffic',
    frameRate: 6,
    description: 'Light Traffic (Highway Slope)',
    size: 2,
    rotate: [421, 418, 419, 420],
    image: '1421',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 422,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Curve)',
    size: 2,
    rotate: [422, 423, 424, 425],
    image: '1422',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 423,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Curve)',
    size: 2,
    rotate: [423, 424, 425, 422],
    image: '1423',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 424,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Curve)',
    size: 2,
    rotate: [424, 425, 422, 423],
    image: '1424',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 425,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Light Traffic (Highway Curve)',
    size: 2,
    rotate: [425, 422, 423, 424],
    image: '1425',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 426,
    type: 'traffic',
    frameRate: 6,
    description: 'Light Traffic (Highway Cloverleaf)',
    size: 2,
    image: '1426',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 427,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (straight)',
    flip: true,
    size: 1,
    image: '1427',
    rotate: [427, 428, 427, 428],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 428,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (straight)',
    flip: true,
    size: 1,
    image: '1428',
    rotate: [428, 427, 428, 427],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 429,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (sloped)',
    size: 1,
    image: '1429',
    rotate: [429, 430, 431, 432],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 430,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (sloped)',
    size: 1,
    image: '1430',
    rotate: [430, 431, 432, 429],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 431,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (sloped)',
    size: 1,
    image: '1431',
    rotate: [431, 432, 429, 430],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 432,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (sloped)',
    size: 1,
    image: '1432',
    rotate: [432, 429, 430, 431],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 433,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (curve)',
    size: 1,
    image: '1433',
    rotate: [433, 434, 435, 436],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 434,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (curve)',
    size: 1,
    image: '1434',
    rotate: [434, 435, 436, 433],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 435,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (curve)',
    size: 1,
    image: '1435',
    rotate: [435, 436, 433, 434],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 436,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (curve)',
    size: 1,
    image: '1436',
    rotate: [436, 433, 434, 435],
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 437,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Straight)',
    size: 1,
    image: '1437',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 438,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Straight)',
    size: 1,
    image: '1438',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 439,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'traffic_40',
    size: 1,
    image: '1439',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 440,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'traffic_41',
    size: 1,
    image: '1440',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 441,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Slope)',
    size: 2,
    rotate: [441, 442, 443, 444],
    image: '1441',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 442,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Slope)',
    size: 2,
    rotate: [442, 443, 444, 441],
    image: '1442',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 443,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Slope)',
    size: 2,
    rotate: [443, 444, 441, 442],
    image: '1443',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 444,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Slope)',
    size: 2,
    rotate: [444, 441, 442, 443],
    image: '1444',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 445,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Curve)',
    size: 2,
    rotate: [445, 446, 447, 448],
    image: '1445',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 446,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Curve)',
    size: 2,
    rotate: [446, 447, 448, 445],
    image: '1446',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 447,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Curve)',
    size: 2,
    rotate: [447, 448, 445, 446],
    image: '1447',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 448,
    type: 'traffic',
    reverseAnimation: true,
    frameRate: 6,
    description: 'Heavy Traffic (Highway Curve)',
    size: 2,
    rotate: [448, 445, 446, 447],
    image: '1448',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 449,
    type: 'traffic',
    frameRate: 6,
    description: 'Heavy Traffic (Highway Cloverleaf)',
    size: 2,
    image: '1449',
    importOptions: {
      dropColor: [161, 177]
    }
  },
  {
    id: 450,
    type: 'pipe',
    description: 'water_pipes_on_1',
    size: 1,
    image: '1450',
  },
  {
    id: 451,
    type: 'pipe',
    description: 'water_pipes_on_2',
    size: 1,
    image: '1451',
  },
  {
    id: 452,
    type: 'pipe',
    description: 'water_pipes_on_3',
    size: 1,
    image: '1452',
  },
  {
    id: 453,
    type: 'pipe',
    description: 'water_pipes_on_4',
    size: 1,
    image: '1453',
  },
  {
    id: 454,
    type: 'pipe',
    description: 'water_pipes_on_5',
    size: 1,
    image: '1454',
  },
  {
    id: 455,
    type: 'pipe',
    description: 'water_pipes_on_6',
    size: 1,
    image: '1455',
  },
  {
    id: 456,
    type: 'pipe',
    description: 'water_pipes_on_7',
    size: 1,
    image: '1456',
  },
  {
    id: 457,
    type: 'pipe',
    description: 'water_pipes_on_8',
    size: 1,
    image: '1457',
  },
  {
    id: 458,
    type: 'pipe',
    description: 'water_pipes_on_9',
    size: 1,
    image: '1458',
  },
  {
    id: 459,
    type: 'pipe',
    description: 'water_pipes_on_10',
    size: 1,
    image: '1459',
  },
  {
    id: 460,
    type: 'pipe',
    description: 'water_pipes_on_11',
    size: 1,
    image: '1460',
  },
  {
    id: 461,
    type: 'pipe',
    description: 'water_pipes_on_12',
    size: 1,
    image: '1461',
  },
  {
    id: 462,
    type: 'pipe',
    description: 'water_pipes_on_13',
    size: 1,
    image: '1462',
  },
  {
    id: 463,
    type: 'pipe',
    description: 'water_pipes_on_14',
    size: 1,
    image: '1463',
  },
  {
    id: 464,
    type: 'pipe',
    description: 'water_pipes_on_15',
    size: 1,
    image: '1464',
  },
  {
    id: 465,
    type: 'pipe',
    subtype: 'subway',
    description: 'subway_water_pipe_on_1',
    size: 1,
    image: '1465',
  },
  {
    id: 466,
    type: 'pipe',
    subtype: 'subway',
    description: 'subway_water_pipe_on_2',
    size: 1,
    image: '1466',
  },
  {
    id: 467,
    type: 'pipe',
    description: 'building_pipes_on',
    size: 1,
    image: '1467',
  },
  {
    id: 468,
    type: 'overlay',
    description: 'density_view_1',
    size: 1,
    image: '1468',
  },
  {
    id: 469,
    type: 'overlay',
    description: 'density_view_2',
    size: 1,
    image: '1469',
  },
  {
    id: 470,
    type: 'overlay',
    description: 'density_view_3',
    size: 1,
    image: '1470',
  },
  {
    id: 471,
    type: 'overlay',
    description: 'density_view_4',
    size: 1,
    image: '1471',
  },
  {
    id: 472,
    type: 'overlay',
    description: 'density_view_5',
    size: 1,
    image: '1472',
  },
  {
    id: 473,
    type: 'overlay',
    description: 'density_view_6',
    size: 1,
    image: '1473',
  },
  {
    id: 474,
    type: 'overlay',
    description: 'density_view_7',
    size: 1,
    image: '1474',
  },
  {
    id: 475,
    type: 'overlay',
    description: 'density_view_8',
    size: 1,
    image: '1475',
  },
  {
    id: 476,
    type: 'overlay',
    description: 'green_plus_tile',
    size: 1,
    image: '1476',
  },
  {
    id: 477,
    type: 'overlay',
    description: 'red_negative_tile',
    size: 1,
    image: '1477',
  },
  {
    id: 478,
    type: 'monster',
    description: 'monster_parts_1',
    size: 2,
    image: '1478',
  },
  {
    id: 479,
    type: 'monster',
    description: 'monster_parts_2',
    size: 2,
    image: '1479',
  },
  {
    id: 480,
    type: 'monster',
    description: 'monster_parts_3',
    size: 2,
    image: '1480',
  },
  {
    id: 481,
    type: 'monster',
    description: 'monster_parts_4',
    size: 2,
    image: '1481',
  },
  {
    id: 482,
    type: 'monster',
    description: 'monster_parts_5',
    size: 2,
    image: '1482',
  },
  {
    id: 483,
    type: 'monster',
    description: 'monster_parts_6',
    size: 2,
    image: '1483',
  },
  {
    id: 484,
    type: 'monster',
    description: 'monster_parts_7',
    size: 2,
    image: '1484',
  },
  {
    id: 485,
    type: 'monster',
    description: 'monster_parts_8',
    size: 2,
    image: '1485',
  },
  {
    id: 486,
    type: 'monster',
    description: 'monster_parts_9',
    size: 2,
    image: '1486',
  },
  {
    id: 487,
    type: 'monster',
    description: 'monster_parts_10',
    size: 2,
    image: '1487',
  },
  {
    id: 488,
    type: 'monster',
    description: 'monster_parts_11',
    size: 2,
    image: '1488',
  },
  {
    id: 489,
    type: 'monster',
    description: 'monster_parts_12',
    size: 2,
    image: '1489',
  },
  {
    id: 490,
    type: 'monster',
    description: 'monster_parts_13',
    size: 2,
    image: '1490',
  },
  {
    id: 491,
    type: 'monster',
    description: 'monster_parts_14',
    size: 2,
    image: '1491',
  },
  {
    id: 492,
    type: 'actor',
    description: 'flood_waters',
    size: 1,
    image: '1492',
  },
  {
    id: 493,
    type: 'actor',
    description: 'rioters_1',
    size: 1,
    image: '1493',
  },
  {
    id: 494,
    type: 'actor',
    description: 'rioters_2',
    size: 1,
    image: '1494',
  },
  {
    id: 495,
    type: 'actor',
    description: 'maxis_man',
    size: 1,
    image: '1495',
  },
  {
    id: 496,
    type: 'actor',
    description: 'cloud',
    size: 2,
    image: '1496',
  },
  {
    id: 497,
    type: 'actor',
    description: 'tornado_1',
    size: 2,
    image: '1497'
  },
  {
    id: 498,
    type: 'actor',
    description: 'tornado_2',
    size: 2,
    image: '1498'
  },
  {
    id: 499,
    type: 'actor',
    description: 'tornado_3',
    size: 2,
    image: '1499'
  }
];

export default data;