/** @license zlib.js 2012 - imaya [ https://github.com/imaya/zlib.js ] The MIT License */
(function() {'use strict';var COMPILED = !0, goog = goog || {};
goog.global = this;
goog.DEBUG = !1;
goog.LOCALE = "en";
goog.provide = function(a) {
  if(!COMPILED) {
    if(goog.isProvided_(a)) {
      throw Error('Namespace "' + a + '" already declared.');
    }
    delete goog.implicitNamespaces_[a];
    for(var b = a;(b = b.substring(0, b.lastIndexOf("."))) && !goog.getObjectByName(b);) {
      goog.implicitNamespaces_[b] = !0
    }
  }
  goog.exportPath_(a)
};
goog.setTestOnly = function(a) {
  if(COMPILED && !goog.DEBUG) {
    throw a = a || "", Error("Importing test-only code into non-debug environment" + a ? ": " + a : ".");
  }
};
COMPILED || (goog.isProvided_ = function(a) {
  return!goog.implicitNamespaces_[a] && !!goog.getObjectByName(a)
}, goog.implicitNamespaces_ = {});
goog.exportPath_ = function(a, b, c) {
  a = a.split(".");
  c = c || goog.global;
  !(a[0] in c) && c.execScript && c.execScript("var " + a[0]);
  for(var d;a.length && (d = a.shift());) {
    !a.length && goog.isDef(b) ? c[d] = b : c = c[d] ? c[d] : c[d] = {}
  }
};
goog.getObjectByName = function(a, b) {
  for(var c = a.split("."), d = b || goog.global, e;e = c.shift();) {
    if(goog.isDefAndNotNull(d[e])) {
      d = d[e]
    }else {
      return null
    }
  }
  return d
};
goog.globalize = function(a, b) {
  var c = b || goog.global, d;
  for(d in a) {
    c[d] = a[d]
  }
};
goog.addDependency = function(a, b, c) {
  if(!COMPILED) {
    for(var d, a = a.replace(/\\/g, "/"), e = goog.dependencies_, f = 0;d = b[f];f++) {
      e.nameToPath[d] = a, a in e.pathToNames || (e.pathToNames[a] = {}), e.pathToNames[a][d] = !0
    }
    for(d = 0;b = c[d];d++) {
      a in e.requires || (e.requires[a] = {}), e.requires[a][b] = !0
    }
  }
};
goog.ENABLE_DEBUG_LOADER = !0;
goog.require = function(a) {
  if(!COMPILED && !goog.isProvided_(a)) {
    if(goog.ENABLE_DEBUG_LOADER) {
      var b = goog.getPathFromDeps_(a);
      if(b) {
        goog.included_[b] = !0;
        goog.writeScripts_();
        return
      }
    }
    a = "goog.require could not find: " + a;
    goog.global.console && goog.global.console.error(a);
    throw Error(a);
  }
};
goog.basePath = "";
goog.nullFunction = function() {
};
goog.identityFunction = function(a) {
  return a
};
goog.abstractMethod = function() {
  throw Error("unimplemented abstract method");
};
goog.addSingletonGetter = function(a) {
  a.getInstance = function() {
    if(a.instance_) {
      return a.instance_
    }
    goog.DEBUG && (goog.instantiatedSingletons_[goog.instantiatedSingletons_.length] = a);
    return a.instance_ = new a
  }
};
goog.instantiatedSingletons_ = [];
!COMPILED && goog.ENABLE_DEBUG_LOADER && (goog.included_ = {}, goog.dependencies_ = {pathToNames:{}, nameToPath:{}, requires:{}, visited:{}, written:{}}, goog.inHtmlDocument_ = function() {
  var a = goog.global.document;
  return"undefined" != typeof a && "write" in a
}, goog.findBasePath_ = function() {
  if(goog.global.CLOSURE_BASE_PATH) {
    goog.basePath = goog.global.CLOSURE_BASE_PATH
  }else {
    if(goog.inHtmlDocument_()) {
      for(var a = goog.global.document.getElementsByTagName("script"), b = a.length - 1;0 <= b;--b) {
        var c = a[b].src, d = c.lastIndexOf("?"), d = -1 == d ? c.length : d;
        if("base.js" == c.substr(d - 7, 7)) {
          goog.basePath = c.substr(0, d - 7);
          break
        }
      }
    }
  }
}, goog.importScript_ = function(a) {
  var b = goog.global.CLOSURE_IMPORT_SCRIPT || goog.writeScriptTag_;
  !goog.dependencies_.written[a] && b(a) && (goog.dependencies_.written[a] = !0)
}, goog.writeScriptTag_ = function(a) {
  return goog.inHtmlDocument_() ? (goog.global.document.write('<script type="text/javascript" src="' + a + '"><\/script>'), !0) : !1
}, goog.writeScripts_ = function() {
  function a(e) {
    if(!(e in d.written)) {
      if(!(e in d.visited) && (d.visited[e] = !0, e in d.requires)) {
        for(var g in d.requires[e]) {
          if(!goog.isProvided_(g)) {
            if(g in d.nameToPath) {
              a(d.nameToPath[g])
            }else {
              throw Error("Undefined nameToPath for " + g);
            }
          }
        }
      }
      e in c || (c[e] = !0, b.push(e))
    }
  }
  var b = [], c = {}, d = goog.dependencies_, e;
  for(e in goog.included_) {
    d.written[e] || a(e)
  }
  for(e = 0;e < b.length;e++) {
    if(b[e]) {
      goog.importScript_(goog.basePath + b[e])
    }else {
      throw Error("Undefined script input");
    }
  }
}, goog.getPathFromDeps_ = function(a) {
  return a in goog.dependencies_.nameToPath ? goog.dependencies_.nameToPath[a] : null
}, goog.findBasePath_(), goog.global.CLOSURE_NO_DEPS || goog.importScript_(goog.basePath + "deps.js"));
goog.typeOf = function(a) {
  var b = typeof a;
  if("object" == b) {
    if(a) {
      if(a instanceof Array) {
        return"array"
      }
      if(a instanceof Object) {
        return b
      }
      var c = Object.prototype.toString.call(a);
      if("[object Window]" == c) {
        return"object"
      }
      if("[object Array]" == c || "number" == typeof a.length && "undefined" != typeof a.splice && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("splice")) {
        return"array"
      }
      if("[object Function]" == c || "undefined" != typeof a.call && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("call")) {
        return"function"
      }
    }else {
      return"null"
    }
  }else {
    if("function" == b && "undefined" == typeof a.call) {
      return"object"
    }
  }
  return b
};
goog.isDef = function(a) {
  return void 0 !== a
};
goog.isNull = function(a) {
  return null === a
};
goog.isDefAndNotNull = function(a) {
  return null != a
};
goog.isArray = function(a) {
  return"array" == goog.typeOf(a)
};
goog.isArrayLike = function(a) {
  var b = goog.typeOf(a);
  return"array" == b || "object" == b && "number" == typeof a.length
};
goog.isDateLike = function(a) {
  return goog.isObject(a) && "function" == typeof a.getFullYear
};
goog.isString = function(a) {
  return"string" == typeof a
};
goog.isBoolean = function(a) {
  return"boolean" == typeof a
};
goog.isNumber = function(a) {
  return"number" == typeof a
};
goog.isFunction = function(a) {
  return"function" == goog.typeOf(a)
};
goog.isObject = function(a) {
  var b = typeof a;
  return"object" == b && null != a || "function" == b
};
goog.getUid = function(a) {
  return a[goog.UID_PROPERTY_] || (a[goog.UID_PROPERTY_] = ++goog.uidCounter_)
};
goog.removeUid = function(a) {
  "removeAttribute" in a && a.removeAttribute(goog.UID_PROPERTY_);
  try {
    delete a[goog.UID_PROPERTY_]
  }catch(b) {
  }
};
goog.UID_PROPERTY_ = "closure_uid_" + Math.floor(2147483648 * Math.random()).toString(36);
goog.uidCounter_ = 0;
goog.getHashCode = goog.getUid;
goog.removeHashCode = goog.removeUid;
goog.cloneObject = function(a) {
  var b = goog.typeOf(a);
  if("object" == b || "array" == b) {
    if(a.clone) {
      return a.clone()
    }
    var b = "array" == b ? [] : {}, c;
    for(c in a) {
      b[c] = goog.cloneObject(a[c])
    }
    return b
  }
  return a
};
goog.bindNative_ = function(a, b, c) {
  return a.call.apply(a.bind, arguments)
};
goog.bindJs_ = function(a, b, c) {
  if(!a) {
    throw Error();
  }
  if(2 < arguments.length) {
    var d = Array.prototype.slice.call(arguments, 2);
    return function() {
      var c = Array.prototype.slice.call(arguments);
      Array.prototype.unshift.apply(c, d);
      return a.apply(b, c)
    }
  }
  return function() {
    return a.apply(b, arguments)
  }
};
goog.bind = function(a, b, c) {
  goog.bind = Function.prototype.bind && -1 != Function.prototype.bind.toString().indexOf("native code") ? goog.bindNative_ : goog.bindJs_;
  return goog.bind.apply(null, arguments)
};
goog.partial = function(a, b) {
  var c = Array.prototype.slice.call(arguments, 1);
  return function() {
    var b = Array.prototype.slice.call(arguments);
    b.unshift.apply(b, c);
    return a.apply(this, b)
  }
};
goog.mixin = function(a, b) {
  for(var c in b) {
    a[c] = b[c]
  }
};
goog.now = Date.now || function() {
  return+new Date
};
goog.globalEval = function(a) {
  if(goog.global.execScript) {
    goog.global.execScript(a, "JavaScript")
  }else {
    if(goog.global.eval) {
      if(null == goog.evalWorksForGlobals_ && (goog.global.eval("var _et_ = 1;"), "undefined" != typeof goog.global._et_ ? (delete goog.global._et_, goog.evalWorksForGlobals_ = !0) : goog.evalWorksForGlobals_ = !1), goog.evalWorksForGlobals_) {
        goog.global.eval(a)
      }else {
        var b = goog.global.document, c = b.createElement("script");
        c.type = "text/javascript";
        c.defer = !1;
        c.appendChild(b.createTextNode(a));
        b.body.appendChild(c);
        b.body.removeChild(c)
      }
    }else {
      throw Error("goog.globalEval not available");
    }
  }
};
goog.evalWorksForGlobals_ = null;
goog.getCssName = function(a, b) {
  var c = function(a) {
    return goog.cssNameMapping_[a] || a
  }, d = function(a) {
    for(var a = a.split("-"), b = [], d = 0;d < a.length;d++) {
      b.push(c(a[d]))
    }
    return b.join("-")
  }, d = goog.cssNameMapping_ ? "BY_WHOLE" == goog.cssNameMappingStyle_ ? c : d : function(a) {
    return a
  };
  return b ? a + "-" + d(b) : d(a)
};
goog.setCssNameMapping = function(a, b) {
  goog.cssNameMapping_ = a;
  goog.cssNameMappingStyle_ = b
};
!COMPILED && goog.global.CLOSURE_CSS_NAME_MAPPING && (goog.cssNameMapping_ = goog.global.CLOSURE_CSS_NAME_MAPPING);
goog.getMsg = function(a, b) {
  var c = b || {}, d;
  for(d in c) {
    var e = ("" + c[d]).replace(/\$/g, "$$$$"), a = a.replace(RegExp("\\{\\$" + d + "\\}", "gi"), e)
  }
  return a
};
goog.exportSymbol = function(a, b, c) {
  goog.exportPath_(a, b, c)
};
goog.exportProperty = function(a, b, c) {
  a[b] = c
};
goog.inherits = function(a, b) {
  function c() {
  }
  c.prototype = b.prototype;
  a.superClass_ = b.prototype;
  a.prototype = new c;
  a.prototype.constructor = a
};
goog.base = function(a, b, c) {
  var d = arguments.callee.caller;
  if(d.superClass_) {
    return d.superClass_.constructor.apply(a, Array.prototype.slice.call(arguments, 1))
  }
  for(var e = Array.prototype.slice.call(arguments, 2), f = !1, g = a.constructor;g;g = g.superClass_ && g.superClass_.constructor) {
    if(g.prototype[b] === d) {
      f = !0
    }else {
      if(f) {
        return g.prototype[b].apply(a, e)
      }
    }
  }
  if(a[b] === d) {
    return a.constructor.prototype[b].apply(a, e)
  }
  throw Error("goog.base called from a method of one name to a method of a different name");
};
goog.scope = function(a) {
  a.call(goog.global)
};
var USE_TYPEDARRAY = "undefined" !== typeof Uint8Array && "undefined" !== typeof Uint16Array && "undefined" !== typeof Uint32Array;
var Zlib = {BitStream:function(a, b) {
  this.index = "number" === typeof b ? b : 0;
  this.bitindex = 0;
  this.buffer = a instanceof (USE_TYPEDARRAY ? Uint8Array : Array) ? a : new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.BitStream.DefaultBlockSize);
  if(2 * this.buffer.length <= this.index) {
    throw Error("invalid index");
  }
  this.buffer.length <= this.index && this.expandBuffer()
}};
Zlib.BitStream.DefaultBlockSize = 32768;
Zlib.BitStream.prototype.expandBuffer = function() {
  var a = this.buffer, b, c = a.length, d = new (USE_TYPEDARRAY ? Uint8Array : Array)(c << 1);
  if(USE_TYPEDARRAY) {
    d.set(a)
  }else {
    for(b = 0;b < c;++b) {
      d[b] = a[b]
    }
  }
  return this.buffer = d
};
Zlib.BitStream.prototype.writeBits = function(a, b, c) {
  var d = this.buffer, e = this.index, f = this.bitindex, g = d[e];
  c && 1 < b && (a = 8 < b ? (Zlib.BitStream.ReverseTable[a & 255] << 24 | Zlib.BitStream.ReverseTable[a >>> 8 & 255] << 16 | Zlib.BitStream.ReverseTable[a >>> 16 & 255] << 8 | Zlib.BitStream.ReverseTable[a >>> 24 & 255]) >> 32 - b : Zlib.BitStream.ReverseTable[a] >> 8 - b);
  if(8 > b + f) {
    g = g << b | a, f += b
  }else {
    for(c = 0;c < b;++c) {
      g = g << 1 | a >> b - c - 1 & 1, 8 === ++f && (f = 0, d[e++] = Zlib.BitStream.ReverseTable[g], g = 0, e === d.length && (d = this.expandBuffer()))
    }
  }
  d[e] = g;
  this.buffer = d;
  this.bitindex = f;
  this.index = e
};
Zlib.BitStream.prototype.finish = function() {
  var a = this.buffer, b = this.index;
  0 < this.bitindex && (a[b] <<= 8 - this.bitindex, a[b] = Zlib.BitStream.ReverseTable[a[b]], b++);
  USE_TYPEDARRAY ? a = a.subarray(0, b) : a.length = b;
  return a
};
Zlib.BitStream.ReverseTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(256), b;
  for(b = 0;256 > b;++b) {
    for(var c = a, d = b, e = b, f = e, g = 7, e = e >>> 1;e;e >>>= 1) {
      f <<= 1, f |= e & 1, --g
    }
    c[d] = (f << g & 255) >>> 0
  }
  return a
}());
Zlib.CRC32 = {};
Zlib.CRC32.calc = function(a, b, c) {
  return Zlib.CRC32.update(a, 0, b, c)
};
Zlib.CRC32.update = function(a, b, c, d) {
  for(var e = Zlib.CRC32.Table, f = "number" === typeof c ? c : c = 0, d = "number" === typeof d ? d : a.length, b = b ^ 4294967295, f = d & 7;f--;++c) {
    b = b >>> 8 ^ e[(b ^ a[c]) & 255]
  }
  for(f = d >> 3;f--;c += 8) {
    b = b >>> 8 ^ e[(b ^ a[c]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 1]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 2]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 3]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 4]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 5]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 6]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 7]) & 255]
  }
  return(b ^ 4294967295) >>> 0
};
Zlib.CRC32.Table = function(a) {
  return USE_TYPEDARRAY ? new Uint32Array(a) : a
}([0, 1996959894, 3993919788, 2567524794, 124634137, 1886057615, 3915621685, 2657392035, 249268274, 2044508324, 3772115230, 2547177864, 162941995, 2125561021, 3887607047, 2428444049, 498536548, 1789927666, 4089016648, 2227061214, 450548861, 1843258603, 4107580753, 2211677639, 325883990, 1684777152, 4251122042, 2321926636, 335633487, 1661365465, 4195302755, 2366115317, 997073096, 1281953886, 3579855332, 2724688242, 1006888145, 1258607687, 3524101629, 2768942443, 901097722, 1119000684, 3686517206, 
2898065728, 853044451, 1172266101, 3705015759, 2882616665, 651767980, 1373503546, 3369554304, 3218104598, 565507253, 1454621731, 3485111705, 3099436303, 671266974, 1594198024, 3322730930, 2970347812, 795835527, 1483230225, 3244367275, 3060149565, 1994146192, 31158534, 2563907772, 4023717930, 1907459465, 112637215, 2680153253, 3904427059, 2013776290, 251722036, 2517215374, 3775830040, 2137656763, 141376813, 2439277719, 3865271297, 1802195444, 476864866, 2238001368, 4066508878, 1812370925, 453092731, 
2181625025, 4111451223, 1706088902, 314042704, 2344532202, 4240017532, 1658658271, 366619977, 2362670323, 4224994405, 1303535960, 984961486, 2747007092, 3569037538, 1256170817, 1037604311, 2765210733, 3554079995, 1131014506, 879679996, 2909243462, 3663771856, 1141124467, 855842277, 2852801631, 3708648649, 1342533948, 654459306, 3188396048, 3373015174, 1466479909, 544179635, 3110523913, 3462522015, 1591671054, 702138776, 2966460450, 3352799412, 1504918807, 783551873, 3082640443, 3233442989, 3988292384, 
2596254646, 62317068, 1957810842, 3939845945, 2647816111, 81470997, 1943803523, 3814918930, 2489596804, 225274430, 2053790376, 3826175755, 2466906013, 167816743, 2097651377, 4027552580, 2265490386, 503444072, 1762050814, 4150417245, 2154129355, 426522225, 1852507879, 4275313526, 2312317920, 282753626, 1742555852, 4189708143, 2394877945, 397917763, 1622183637, 3604390888, 2714866558, 953729732, 1340076626, 3518719985, 2797360999, 1068828381, 1219638859, 3624741850, 2936675148, 906185462, 1090812512, 
3747672003, 2825379669, 829329135, 1181335161, 3412177804, 3160834842, 628085408, 1382605366, 3423369109, 3138078467, 570562233, 1426400815, 3317316542, 2998733608, 733239954, 1555261956, 3268935591, 3050360625, 752459403, 1541320221, 2607071920, 3965973030, 1969922972, 40735498, 2617837225, 3943577151, 1913087877, 83908371, 2512341634, 3803740692, 2075208622, 213261112, 2463272603, 3855990285, 2094854071, 198958881, 2262029012, 4057260610, 1759359992, 534414190, 2176718541, 4139329115, 1873836001, 
414664567, 2282248934, 4279200368, 1711684554, 285281116, 2405801727, 4167216745, 1634467795, 376229701, 2685067896, 3608007406, 1308918612, 956543938, 2808555105, 3495958263, 1231636301, 1047427035, 2932959818, 3654703836, 1088359270, 936918E3, 2847714899, 3736837829, 1202900863, 817233897, 3183342108, 3401237130, 1404277552, 615818150, 3134207493, 3453421203, 1423857449, 601450431, 3009837614, 3294710456, 1567103746, 711928724, 3020668471, 3272380065, 1510334235, 755167117]);
Zlib.exportObject = function(a, b) {
  var c, d, e, f;
  if(Object.keys) {
    c = Object.keys(b)
  }else {
    for(d in c = [], e = 0, b) {
      c[e++] = d
    }
  }
  e = 0;
  for(f = c.length;e < f;++e) {
    d = c[e], goog.exportSymbol(a + "." + d, b[d])
  }
};
Zlib.GunzipMember = function() {
};
Zlib.GunzipMember.prototype.getName = function() {
  return this.name
};
Zlib.GunzipMember.prototype.getData = function() {
  return this.data
};
Zlib.GunzipMember.prototype.getMtime = function() {
  return this.mtime
};
Zlib.Heap = function(a) {
  this.buffer = new (USE_TYPEDARRAY ? Uint16Array : Array)(2 * a);
  this.length = 0
};
Zlib.Heap.prototype.getParent = function(a) {
  return 2 * ((a - 2) / 4 | 0)
};
Zlib.Heap.prototype.getChild = function(a) {
  return 2 * a + 2
};
Zlib.Heap.prototype.push = function(a, b) {
  var c, d, e = this.buffer, f;
  c = this.length;
  e[this.length++] = b;
  for(e[this.length++] = a;0 < c;) {
    if(d = this.getParent(c), e[c] > e[d]) {
      f = e[c], e[c] = e[d], e[d] = f, f = e[c + 1], e[c + 1] = e[d + 1], e[d + 1] = f, c = d
    }else {
      break
    }
  }
  return this.length
};
Zlib.Heap.prototype.pop = function() {
  var a, b, c = this.buffer, d, e, f;
  b = c[0];
  a = c[1];
  this.length -= 2;
  c[0] = c[this.length];
  c[1] = c[this.length + 1];
  for(f = 0;;) {
    e = this.getChild(f);
    if(e >= this.length) {
      break
    }
    e + 2 < this.length && c[e + 2] > c[e] && (e += 2);
    if(c[e] > c[f]) {
      d = c[f], c[f] = c[e], c[e] = d, d = c[f + 1], c[f + 1] = c[e + 1], c[e + 1] = d
    }else {
      break
    }
    f = e
  }
  return{index:a, value:b, length:this.length}
};
Zlib.Huffman = {};
Zlib.Huffman.buildHuffmanTable = function(a) {
  var b = a.length, c = 0, d = Number.POSITIVE_INFINITY, e, f, g, h, i, j, l, m, k;
  for(m = 0;m < b;++m) {
    a[m] > c && (c = a[m]), a[m] < d && (d = a[m])
  }
  e = 1 << c;
  f = new (USE_TYPEDARRAY ? Uint32Array : Array)(e);
  g = 1;
  h = 0;
  for(i = 2;g <= c;) {
    for(m = 0;m < b;++m) {
      if(a[m] === g) {
        j = 0;
        l = h;
        for(k = 0;k < g;++k) {
          j = j << 1 | l & 1, l >>= 1
        }
        for(k = j;k < e;k += i) {
          f[k] = g << 16 | m
        }
        ++h
      }
    }
    ++g;
    h <<= 1;
    i <<= 1
  }
  return[f, c, d]
};
Zlib.RawDeflate = function(a, b) {
  this.compressionType = Zlib.RawDeflate.CompressionType.DYNAMIC;
  this.lazy = 0;
  this.input = a;
  this.op = 0;
  b && (b.lazy && (this.lazy = b.lazy), "number" === typeof b.compressionType && (this.compressionType = b.compressionType), b.outputBuffer && (this.output = USE_TYPEDARRAY && b.outputBuffer instanceof Array ? new Uint8Array(b.outputBuffer) : b.outputBuffer), "number" === typeof b.outputIndex && (this.op = b.outputIndex));
  this.output || (this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(32768))
};
Zlib.RawDeflate.CompressionType = {NONE:0, FIXED:1, DYNAMIC:2, RESERVED:3};
Zlib.RawDeflate.Lz77MinLength = 3;
Zlib.RawDeflate.Lz77MaxLength = 258;
Zlib.RawDeflate.WindowSize = 32768;
Zlib.RawDeflate.MaxCodeLength = 16;
Zlib.RawDeflate.HUFMAX = 286;
Zlib.RawDeflate.FixedHuffmanTable = function() {
  var a = [], b;
  for(b = 0;288 > b;b++) {
    switch(!0) {
      case 143 >= b:
        a.push([b + 48, 8]);
        break;
      case 255 >= b:
        a.push([b - 144 + 400, 9]);
        break;
      case 279 >= b:
        a.push([b - 256 + 0, 7]);
        break;
      case 287 >= b:
        a.push([b - 280 + 192, 8]);
        break;
      default:
        throw"invalid literal: " + b;
    }
  }
  return a
}();
Zlib.RawDeflate.prototype.compress = function() {
  var a, b, c, d = this.input;
  switch(this.compressionType) {
    case Zlib.RawDeflate.CompressionType.NONE:
      b = 0;
      for(c = d.length;b < c;) {
        a = USE_TYPEDARRAY ? d.subarray(b, b + 65535) : d.slice(b, b + 65535), b += a.length, this.makeNocompressBlock(a, b === c)
      }
      break;
    case Zlib.RawDeflate.CompressionType.FIXED:
      this.output = this.makeFixedHuffmanBlock(d, !0);
      this.op = this.output.length;
      break;
    case Zlib.RawDeflate.CompressionType.DYNAMIC:
      this.output = this.makeDynamicHuffmanBlock(d, !0);
      this.op = this.output.length;
      break;
    default:
      throw"invalid compression type";
  }
  return this.output
};
Zlib.RawDeflate.prototype.makeNocompressBlock = function(a, b) {
  var c, d, e = this.output, f = this.op;
  if(USE_TYPEDARRAY) {
    for(e = new Uint8Array(this.output.buffer);e.length <= f + a.length + 5;) {
      e = new Uint8Array(e.length << 1)
    }
    e.set(this.output)
  }
  c = Zlib.RawDeflate.CompressionType.NONE;
  e[f++] = (b ? 1 : 0) | c << 1;
  c = a.length;
  d = ~c + 65536 & 65535;
  e[f++] = c & 255;
  e[f++] = c >>> 8 & 255;
  e[f++] = d & 255;
  e[f++] = d >>> 8 & 255;
  if(USE_TYPEDARRAY) {
    e.set(a, f), f += a.length, e = e.subarray(0, f)
  }else {
    c = 0;
    for(d = a.length;c < d;++c) {
      e[f++] = a[c]
    }
    e.length = f
  }
  this.op = f;
  return this.output = e
};
Zlib.RawDeflate.prototype.makeFixedHuffmanBlock = function(a, b) {
  var c = new Zlib.BitStream(new Uint8Array(this.output.buffer), this.op), d;
  d = Zlib.RawDeflate.CompressionType.FIXED;
  c.writeBits(b ? 1 : 0, 1, !0);
  c.writeBits(d, 2, !0);
  d = this.lz77(a);
  this.fixedHuffman(d, c);
  return c.finish()
};
Zlib.RawDeflate.prototype.makeDynamicHuffmanBlock = function(a, b) {
  var c = new Zlib.BitStream(new Uint8Array(this.output), this.op), d, e, f, g, h = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15], i, j, l, m, k, n, q = Array(19), p;
  d = Zlib.RawDeflate.CompressionType.DYNAMIC;
  c.writeBits(b ? 1 : 0, 1, !0);
  c.writeBits(d, 2, !0);
  d = this.lz77(a);
  i = this.getLengths_(this.freqsLitLen, 15);
  j = this.getCodesFromLengths_(i);
  l = this.getLengths_(this.freqsDist, 7);
  m = this.getCodesFromLengths_(l);
  for(e = 286;257 < e && 0 === i[e - 1];e--) {
  }
  for(f = 30;1 < f && 0 === l[f - 1];f--) {
  }
  k = this.getTreeSymbols_(e, i, f, l);
  n = this.getLengths_(k.freqs, 7);
  for(p = 0;19 > p;p++) {
    q[p] = n[h[p]]
  }
  for(g = 19;4 < g && 0 === q[g - 1];g--) {
  }
  h = this.getCodesFromLengths_(n);
  c.writeBits(e - 257, 5, !0);
  c.writeBits(f - 1, 5, !0);
  c.writeBits(g - 4, 4, !0);
  for(p = 0;p < g;p++) {
    c.writeBits(q[p], 3, !0)
  }
  p = 0;
  for(q = k.codes.length;p < q;p++) {
    if(e = k.codes[p], c.writeBits(h[e], n[e], !0), 16 <= e) {
      p++;
      switch(e) {
        case 16:
          e = 2;
          break;
        case 17:
          e = 3;
          break;
        case 18:
          e = 7;
          break;
        default:
          throw"invalid code: " + e;
      }
      c.writeBits(k.codes[p], e, !0)
    }
  }
  this.dynamicHuffman(d, [j, i], [m, l], c);
  return c.finish()
};
Zlib.RawDeflate.prototype.dynamicHuffman = function(a, b, c, d) {
  var e, f, g, h, i;
  g = b[0];
  b = b[1];
  h = c[0];
  i = c[1];
  c = 0;
  for(e = a.length;c < e;++c) {
    if(f = a[c], d.writeBits(g[f], b[f], !0), 256 < f) {
      d.writeBits(a[++c], a[++c], !0), f = a[++c], d.writeBits(h[f], i[f], !0), d.writeBits(a[++c], a[++c], !0)
    }else {
      if(256 === f) {
        break
      }
    }
  }
  return d
};
Zlib.RawDeflate.prototype.fixedHuffman = function(a, b) {
  var c, d, e;
  c = 0;
  for(d = a.length;c < d;c++) {
    if(e = a[c], Zlib.BitStream.prototype.writeBits.apply(b, Zlib.RawDeflate.FixedHuffmanTable[e]), 256 < e) {
      b.writeBits(a[++c], a[++c], !0), b.writeBits(a[++c], 5), b.writeBits(a[++c], a[++c], !0)
    }else {
      if(256 === e) {
        break
      }
    }
  }
  return b
};
Zlib.RawDeflate.Lz77Match = function(a, b) {
  this.length = a;
  this.backwardDistance = b
};
Zlib.RawDeflate.Lz77Match.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint32Array(a) : a
}(function() {
  function a(a) {
    switch(!0) {
      case 3 === a:
        return[257, a - 3, 0];
      case 4 === a:
        return[258, a - 4, 0];
      case 5 === a:
        return[259, a - 5, 0];
      case 6 === a:
        return[260, a - 6, 0];
      case 7 === a:
        return[261, a - 7, 0];
      case 8 === a:
        return[262, a - 8, 0];
      case 9 === a:
        return[263, a - 9, 0];
      case 10 === a:
        return[264, a - 10, 0];
      case 12 >= a:
        return[265, a - 11, 1];
      case 14 >= a:
        return[266, a - 13, 1];
      case 16 >= a:
        return[267, a - 15, 1];
      case 18 >= a:
        return[268, a - 17, 1];
      case 22 >= a:
        return[269, a - 19, 2];
      case 26 >= a:
        return[270, a - 23, 2];
      case 30 >= a:
        return[271, a - 27, 2];
      case 34 >= a:
        return[272, a - 31, 2];
      case 42 >= a:
        return[273, a - 35, 3];
      case 50 >= a:
        return[274, a - 43, 3];
      case 58 >= a:
        return[275, a - 51, 3];
      case 66 >= a:
        return[276, a - 59, 3];
      case 82 >= a:
        return[277, a - 67, 4];
      case 98 >= a:
        return[278, a - 83, 4];
      case 114 >= a:
        return[279, a - 99, 4];
      case 130 >= a:
        return[280, a - 115, 4];
      case 162 >= a:
        return[281, a - 131, 5];
      case 194 >= a:
        return[282, a - 163, 5];
      case 226 >= a:
        return[283, a - 195, 5];
      case 257 >= a:
        return[284, a - 227, 5];
      case 258 === a:
        return[285, a - 258, 0];
      default:
        throw"invalid length: " + a;
    }
  }
  var b = [], c, d;
  for(c = 3;258 >= c;c++) {
    d = a(c), b[c] = d[2] << 24 | d[1] << 16 | d[0]
  }
  return b
}());
Zlib.RawDeflate.Lz77Match.prototype.getDistanceCode_ = function(a) {
  switch(!0) {
    case 1 === a:
      a = [0, a - 1, 0];
      break;
    case 2 === a:
      a = [1, a - 2, 0];
      break;
    case 3 === a:
      a = [2, a - 3, 0];
      break;
    case 4 === a:
      a = [3, a - 4, 0];
      break;
    case 6 >= a:
      a = [4, a - 5, 1];
      break;
    case 8 >= a:
      a = [5, a - 7, 1];
      break;
    case 12 >= a:
      a = [6, a - 9, 2];
      break;
    case 16 >= a:
      a = [7, a - 13, 2];
      break;
    case 24 >= a:
      a = [8, a - 17, 3];
      break;
    case 32 >= a:
      a = [9, a - 25, 3];
      break;
    case 48 >= a:
      a = [10, a - 33, 4];
      break;
    case 64 >= a:
      a = [11, a - 49, 4];
      break;
    case 96 >= a:
      a = [12, a - 65, 5];
      break;
    case 128 >= a:
      a = [13, a - 97, 5];
      break;
    case 192 >= a:
      a = [14, a - 129, 6];
      break;
    case 256 >= a:
      a = [15, a - 193, 6];
      break;
    case 384 >= a:
      a = [16, a - 257, 7];
      break;
    case 512 >= a:
      a = [17, a - 385, 7];
      break;
    case 768 >= a:
      a = [18, a - 513, 8];
      break;
    case 1024 >= a:
      a = [19, a - 769, 8];
      break;
    case 1536 >= a:
      a = [20, a - 1025, 9];
      break;
    case 2048 >= a:
      a = [21, a - 1537, 9];
      break;
    case 3072 >= a:
      a = [22, a - 2049, 10];
      break;
    case 4096 >= a:
      a = [23, a - 3073, 10];
      break;
    case 6144 >= a:
      a = [24, a - 4097, 11];
      break;
    case 8192 >= a:
      a = [25, a - 6145, 11];
      break;
    case 12288 >= a:
      a = [26, a - 8193, 12];
      break;
    case 16384 >= a:
      a = [27, a - 12289, 12];
      break;
    case 24576 >= a:
      a = [28, a - 16385, 13];
      break;
    case 32768 >= a:
      a = [29, a - 24577, 13];
      break;
    default:
      throw"invalid distance";
  }
  return a
};
Zlib.RawDeflate.Lz77Match.prototype.toLz77Array = function() {
  var a = this.backwardDistance, b = [], c = 0, d;
  d = Zlib.RawDeflate.Lz77Match.LengthCodeTable[this.length];
  b[c++] = d & 65535;
  b[c++] = d >> 16 & 255;
  b[c++] = d >> 24;
  d = this.getDistanceCode_(a);
  b[c++] = d[0];
  b[c++] = d[1];
  b[c++] = d[2];
  return b
};
Zlib.RawDeflate.prototype.lz77 = function(a) {
  function b(a, b) {
    var c = a.toLz77Array(), d, e;
    d = 0;
    for(e = c.length;d < e;++d) {
      l[m++] = c[d]
    }
    n[c[0]]++;
    q[c[3]]++;
    k = a.length + b - 1;
    j = null
  }
  var c, d, e, f, g, h = {}, i = Zlib.RawDeflate.WindowSize, j, l = USE_TYPEDARRAY ? new Uint16Array(2 * a.length) : [], m = 0, k = 0, n = new (USE_TYPEDARRAY ? Uint32Array : Array)(286), q = new (USE_TYPEDARRAY ? Uint32Array : Array)(30), p = this.lazy;
  if(!USE_TYPEDARRAY) {
    for(e = 0;285 >= e;) {
      n[e++] = 0
    }
    for(e = 0;29 >= e;) {
      q[e++] = 0
    }
  }
  n[256] = 1;
  c = 0;
  for(d = a.length;c < d;++c) {
    e = g = 0;
    for(f = Zlib.RawDeflate.Lz77MinLength;e < f && c + e !== d;++e) {
      g = g << 8 | a[c + e]
    }
    void 0 === h[g] && (h[g] = []);
    e = h[g];
    if(!(0 < k--)) {
      for(;0 < e.length && c - e[0] > i;) {
        e.shift()
      }
      if(c + Zlib.RawDeflate.Lz77MinLength >= d) {
        j && b(j, -1);
        e = 0;
        for(f = d - c;e < f;++e) {
          g = a[c + e], l[m++] = g, ++n[g]
        }
        break
      }
      0 < e.length ? (f = this.searchLongestMatch_(a, c, e), j ? j.length < f.length ? (g = a[c - 1], l[m++] = g, ++n[g], b(f, 0)) : b(j, -1) : f.length < p ? j = f : b(f, 0)) : j ? b(j, -1) : (g = a[c], l[m++] = g, ++n[g])
    }
    e.push(c)
  }
  l[m++] = 256;
  n[256]++;
  this.freqsLitLen = n;
  this.freqsDist = q;
  return USE_TYPEDARRAY ? l.subarray(0, m) : l
};
Zlib.RawDeflate.prototype.searchLongestMatch_ = function(a, b, c) {
  var d, e, f = 0, g, h, i, j = a.length;
  h = 0;
  i = c.length;
  a:for(;h < i;h++) {
    d = c[i - h - 1];
    g = Zlib.RawDeflate.Lz77MinLength;
    if(f > Zlib.RawDeflate.Lz77MinLength) {
      for(g = f;g > Zlib.RawDeflate.Lz77MinLength;g--) {
        if(a[d + g - 1] !== a[b + g - 1]) {
          continue a
        }
      }
      g = f
    }
    for(;g < Zlib.RawDeflate.Lz77MaxLength && b + g < j && a[d + g] === a[b + g];) {
      ++g
    }
    g > f && (e = d, f = g);
    if(g === Zlib.RawDeflate.Lz77MaxLength) {
      break
    }
  }
  return new Zlib.RawDeflate.Lz77Match(f, b - e)
};
Zlib.RawDeflate.prototype.getTreeSymbols_ = function(a, b, c, d) {
  var e = new (USE_TYPEDARRAY ? Uint32Array : Array)(a + c), f, g, h = new (USE_TYPEDARRAY ? Uint32Array : Array)(316), i = new (USE_TYPEDARRAY ? Uint8Array : Array)(19);
  for(f = g = 0;f < a;f++) {
    e[g++] = b[f]
  }
  for(f = 0;f < c;f++) {
    e[g++] = d[f]
  }
  if(!USE_TYPEDARRAY) {
    f = 0;
    for(b = i.length;f < b;++f) {
      i[f] = 0
    }
  }
  f = c = 0;
  for(b = e.length;f < b;f += g) {
    for(g = 1;f + g < b && e[f + g] === e[f];++g) {
    }
    a = g;
    if(0 === e[f]) {
      if(3 > a) {
        for(;0 < a--;) {
          h[c++] = 0, i[0]++
        }
      }else {
        for(;0 < a;) {
          d = 138 > a ? a : 138, d > a - 3 && d < a && (d = a - 3), 10 >= d ? (h[c++] = 17, h[c++] = d - 3, i[17]++) : (h[c++] = 18, h[c++] = d - 11, i[18]++), a -= d
        }
      }
    }else {
      if(h[c++] = e[f], i[e[f]]++, a--, 3 > a) {
        for(;0 < a--;) {
          h[c++] = e[f], i[e[f]]++
        }
      }else {
        for(;0 < a;) {
          d = 6 > a ? a : 6, d > a - 3 && d < a && (d = a - 3), h[c++] = 16, h[c++] = d - 3, i[16]++, a -= d
        }
      }
    }
  }
  return{codes:USE_TYPEDARRAY ? h.subarray(0, c) : h.slice(0, c), freqs:i}
};
Zlib.RawDeflate.prototype.getLengths_ = function(a, b) {
  var c = a.length, d = new Zlib.Heap(2 * Zlib.RawDeflate.HUFMAX), e = new (USE_TYPEDARRAY ? Uint8Array : Array)(c), f, g, h;
  if(!USE_TYPEDARRAY) {
    for(g = 0;g < c;g++) {
      e[g] = 0
    }
  }
  for(g = 0;g < c;++g) {
    0 < a[g] && d.push(g, a[g])
  }
  c = Array(d.length / 2);
  f = new (USE_TYPEDARRAY ? Uint32Array : Array)(d.length / 2);
  if(1 === c.length) {
    return e[d.pop().index] = 1, e
  }
  g = 0;
  for(h = d.length / 2;g < h;++g) {
    c[g] = d.pop(), f[g] = c[g].value
  }
  d = this.reversePackageMerge_(f, f.length, b);
  g = 0;
  for(h = c.length;g < h;++g) {
    e[c[g].index] = d[g]
  }
  return e
};
Zlib.RawDeflate.prototype.reversePackageMerge_ = function(a, b, c) {
  function d(a) {
    var c = i[a][j[a]];
    c === b ? (d(a + 1), d(a + 1)) : --g[c];
    ++j[a]
  }
  var e = new (USE_TYPEDARRAY ? Uint16Array : Array)(c), f = new (USE_TYPEDARRAY ? Uint8Array : Array)(c), g = new (USE_TYPEDARRAY ? Uint8Array : Array)(b), h = Array(c), i = Array(c), j = Array(c), l = (1 << c) - b, m = 1 << c - 1, k, n;
  e[c - 1] = b;
  for(k = 0;k < c;++k) {
    l < m ? f[k] = 0 : (f[k] = 1, l -= m), l <<= 1, e[c - 2 - k] = (e[c - 1 - k] / 2 | 0) + b
  }
  e[0] = f[0];
  h[0] = Array(e[0]);
  i[0] = Array(e[0]);
  for(k = 1;k < c;++k) {
    e[k] > 2 * e[k - 1] + f[k] && (e[k] = 2 * e[k - 1] + f[k]), h[k] = Array(e[k]), i[k] = Array(e[k])
  }
  for(l = 0;l < b;++l) {
    g[l] = c
  }
  for(m = 0;m < e[c - 1];++m) {
    h[c - 1][m] = a[m], i[c - 1][m] = m
  }
  for(l = 0;l < c;++l) {
    j[l] = 0
  }
  1 === f[c - 1] && (--g[0], ++j[c - 1]);
  for(k = c - 2;0 <= k;--k) {
    c = l = 0;
    n = j[k + 1];
    for(m = 0;m < e[k];m++) {
      c = h[k + 1][n] + h[k + 1][n + 1], c > a[l] ? (h[k][m] = c, i[k][m] = b, n += 2) : (h[k][m] = a[l], i[k][m] = l, ++l)
    }
    j[k] = 0;
    1 === f[k] && d(k)
  }
  return g
};
Zlib.RawDeflate.prototype.getCodesFromLengths_ = function(a) {
  var b = new (USE_TYPEDARRAY ? Uint16Array : Array)(a.length), c = [], d = [], e = 0, f, g, h;
  f = 0;
  for(g = a.length;f < g;f++) {
    c[a[f]] = (c[a[f]] | 0) + 1
  }
  f = 1;
  for(g = Zlib.RawDeflate.MaxCodeLength;f <= g;f++) {
    d[f] = e, e += c[f] | 0, e <<= 1
  }
  f = 0;
  for(g = a.length;f < g;f++) {
    e = d[a[f]];
    d[a[f]] += 1;
    c = b[f] = 0;
    for(h = a[f];c < h;c++) {
      b[f] = b[f] << 1 | e & 1, e >>>= 1
    }
  }
  return b
};
Zlib.Gzip = function(a, b) {
  this.input = a;
  this.op = this.ip = 0;
  this.flags = {};
  b && (b.flags && (this.flags = b.flags), "string" === typeof b.filename && (this.filename = b.filename), "string" === typeof b.comment && (this.comment = b.comment), b.deflateOptions && (this.deflateOptions = b.deflateOptions));
  this.deflateOptions || (this.deflateOptions = {})
};
Zlib.Gzip.DefaultBufferSize = 32768;
Zlib.Gzip.prototype.compress = function() {
  var a, b, c, d, e, f = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.Gzip.DefaultBufferSize);
  c = 0;
  var g = this.input, h = this.ip;
  b = this.filename;
  var i = this.comment;
  f[c++] = 31;
  f[c++] = 139;
  f[c++] = 8;
  a = 0;
  this.flags.fname && (a |= Zlib.Gzip.FlagsMask.FNAME);
  this.flags.fcomment && (a |= Zlib.Gzip.FlagsMask.FCOMMENT);
  this.flags.fhcrc && (a |= Zlib.Gzip.FlagsMask.FHCRC);
  f[c++] = a;
  a = (Date.now ? Date.now() : +new Date) / 1E3 | 0;
  f[c++] = a & 255;
  f[c++] = a >>> 8 & 255;
  f[c++] = a >>> 16 & 255;
  f[c++] = a >>> 24 & 255;
  f[c++] = 0;
  f[c++] = Zlib.Gzip.OperatingSystem.UNKNOWN;
  if(void 0 !== this.flags.fname) {
    d = 0;
    for(e = b.length;d < e;++d) {
      a = b.charCodeAt(d), 255 < a && (f[c++] = a >>> 8 & 255), f[c++] = a & 255
    }
    f[c++] = 0
  }
  if(this.flags.comment) {
    d = 0;
    for(e = i.length;d < e;++d) {
      a = i.charCodeAt(d), 255 < a && (f[c++] = a >>> 8 & 255), f[c++] = a & 255
    }
    f[c++] = 0
  }
  this.flags.fhcrc && (b = Zlib.CRC32.calc(f, 0, c) & 65535, f[c++] = b & 255, f[c++] = b >>> 8 & 255);
  this.deflateOptions.outputBuffer = f;
  this.deflateOptions.outputIndex = c;
  c = new Zlib.RawDeflate(g, this.deflateOptions);
  f = c.compress();
  c = c.op;
  USE_TYPEDARRAY && (c + 8 > f.buffer.byteLength ? (this.output = new Uint8Array(c + 8), this.output.set(new Uint8Array(f.buffer)), f = this.output) : f = new Uint8Array(f.buffer));
  b = Zlib.CRC32.calc(g);
  f[c++] = b & 255;
  f[c++] = b >>> 8 & 255;
  f[c++] = b >>> 16 & 255;
  f[c++] = b >>> 24 & 255;
  e = g.length;
  f[c++] = e & 255;
  f[c++] = e >>> 8 & 255;
  f[c++] = e >>> 16 & 255;
  f[c++] = e >>> 24 & 255;
  this.ip = h;
  USE_TYPEDARRAY && c < f.length && (this.output = f = f.subarray(0, c));
  return f
};
Zlib.Gzip.OperatingSystem = {FAT:0, AMIGA:1, VMS:2, UNIX:3, VM_CMS:4, ATARI_TOS:5, HPFS:6, MACINTOSH:7, Z_SYSTEM:8, CP_M:9, TOPS_20:10, NTFS:11, QDOS:12, ACORN_RISCOS:13, UNKNOWN:255};
Zlib.Gzip.FlagsMask = {FTEXT:1, FHCRC:2, FEXTRA:4, FNAME:8, FCOMMENT:16};
var ZLIB_RAW_INFLATE_BUFFER_SIZE = 32768;
Zlib.RawInflate = function(a, b) {
  this.blocks = [];
  this.bufferSize = ZLIB_RAW_INFLATE_BUFFER_SIZE;
  this.bitsbuflen = this.bitsbuf = this.ip = this.totalpos = 0;
  this.input = USE_TYPEDARRAY ? new Uint8Array(a) : a;
  this.bfinal = !1;
  this.bufferType = Zlib.RawInflate.BufferType.ADAPTIVE;
  this.resize = !1;
  if(b || !(b = {})) {
    b.index && (this.ip = b.index), b.bufferSize && (this.bufferSize = b.bufferSize), b.bufferType && (this.bufferType = b.bufferType), b.resize && (this.resize = b.resize)
  }
  switch(this.bufferType) {
    case Zlib.RawInflate.BufferType.BLOCK:
      this.op = Zlib.RawInflate.MaxBackwardLength;
      this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflate.MaxBackwardLength + this.bufferSize + Zlib.RawInflate.MaxCopyLength);
      break;
    case Zlib.RawInflate.BufferType.ADAPTIVE:
      this.op = 0;
      this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.bufferSize);
      this.expandBuffer = this.expandBufferAdaptive;
      this.concatBuffer = this.concatBufferDynamic;
      this.decodeHuffman = this.decodeHuffmanAdaptive;
      break;
    default:
      throw Error("invalid inflate mode");
  }
};
Zlib.RawInflate.BufferType = {BLOCK:0, ADAPTIVE:1};
Zlib.RawInflate.prototype.decompress = function() {
  for(;!this.bfinal;) {
    this.parseBlock()
  }
  return this.concatBuffer()
};
Zlib.RawInflate.MaxBackwardLength = 32768;
Zlib.RawInflate.MaxCopyLength = 258;
Zlib.RawInflate.Order = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
Zlib.RawInflate.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 258, 258]);
Zlib.RawInflate.LengthExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0]);
Zlib.RawInflate.DistCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]);
Zlib.RawInflate.DistExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
Zlib.RawInflate.FixedLiteralLengthTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(288), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 143 >= b ? 8 : 255 >= b ? 9 : 279 >= b ? 7 : 8
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflate.FixedDistanceTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(30), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 5
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflate.prototype.parseBlock = function() {
  var a = this.readBits(3);
  a & 1 && (this.bfinal = !0);
  a >>>= 1;
  switch(a) {
    case 0:
      this.parseUncompressedBlock();
      break;
    case 1:
      this.parseFixedHuffmanBlock();
      break;
    case 2:
      this.parseDynamicHuffmanBlock();
      break;
    default:
      throw Error("unknown BTYPE: " + a);
  }
};
Zlib.RawInflate.prototype.readBits = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f;c < a;) {
    f = d[e++];
    if(void 0 === f) {
      throw Error("input buffer is broken");
    }
    b |= f << c;
    c += 8
  }
  f = b & (1 << a) - 1;
  this.bitsbuf = b >>> a;
  this.bitsbuflen = c - a;
  this.ip = e;
  return f
};
Zlib.RawInflate.prototype.readCodeByTable = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f = a[0], a = a[1], g;c < a;) {
    g = d[e++];
    if(void 0 === g) {
      throw Error("input buffer is broken");
    }
    b |= g << c;
    c += 8
  }
  d = f[b & (1 << a) - 1];
  f = d >>> 16;
  this.bitsbuf = b >> f;
  this.bitsbuflen = c - f;
  this.ip = e;
  return d & 65535
};
Zlib.RawInflate.prototype.parseUncompressedBlock = function() {
  var a = this.input, b = this.ip, c = this.output, d = this.op, e, f, g, h = c.length;
  this.bitsbuflen = this.bitsbuf = 0;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: LEN (first byte)");
  }
  f = e;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: LEN (second byte)");
  }
  f |= e << 8;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: NLEN (first byte)");
  }
  g = e;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: NLEN (second byte)");
  }
  if(f === ~(g | e << 8)) {
    throw Error("invalid uncompressed block header: length verify");
  }
  if(b + f > a.length) {
    throw Error("input buffer is broken");
  }
  switch(this.bufferType) {
    case Zlib.RawInflate.BufferType.BLOCK:
      for(;d + f > c.length;) {
        e = h - d;
        f -= e;
        if(USE_TYPEDARRAY) {
          c.set(a.subarray(b, b + e), d), d += e, b += e
        }else {
          for(;e--;) {
            c[d++] = a[b++]
          }
        }
        this.op = d;
        c = this.expandBuffer();
        d = this.op
      }
      break;
    case Zlib.RawInflate.BufferType.ADAPTIVE:
      for(;d + f > c.length;) {
        c = this.expandBuffer({fixRatio:2})
      }
      break;
    default:
      throw Error("invalid inflate mode");
  }
  if(USE_TYPEDARRAY) {
    c.set(a.subarray(b, b + f), d), d += f, b += f
  }else {
    for(;f--;) {
      c[d++] = a[b++]
    }
  }
  this.ip = b;
  this.op = d;
  this.output = c
};
Zlib.RawInflate.prototype.parseFixedHuffmanBlock = function() {
  this.decodeHuffman(Zlib.RawInflate.FixedLiteralLengthTable, Zlib.RawInflate.FixedDistanceTable)
};
Zlib.RawInflate.prototype.parseDynamicHuffmanBlock = function() {
  function a(a, b, c) {
    var d, e, f;
    for(f = 0;f < a;) {
      switch(d = this.readCodeByTable(b), d) {
        case 16:
          for(d = 3 + this.readBits(2);d--;) {
            c[f++] = e
          }
          break;
        case 17:
          for(d = 3 + this.readBits(3);d--;) {
            c[f++] = 0
          }
          e = 0;
          break;
        case 18:
          for(d = 11 + this.readBits(7);d--;) {
            c[f++] = 0
          }
          e = 0;
          break;
        default:
          e = c[f++] = d
      }
    }
    return c
  }
  var b = this.readBits(5) + 257, c = this.readBits(5) + 1, d = this.readBits(4) + 4, e = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflate.Order.length), f;
  for(f = 0;f < d;++f) {
    e[Zlib.RawInflate.Order[f]] = this.readBits(3)
  }
  d = (0,Zlib.Huffman.buildHuffmanTable)(e);
  e = new (USE_TYPEDARRAY ? Uint8Array : Array)(b);
  f = new (USE_TYPEDARRAY ? Uint8Array : Array)(c);
  this.decodeHuffman((0,Zlib.Huffman.buildHuffmanTable)(a.call(this, b, d, e)), (0,Zlib.Huffman.buildHuffmanTable)(a.call(this, c, d, f)))
};
Zlib.RawInflate.prototype.decodeHuffman = function(a, b) {
  var c = this.output, d = this.op;
  this.currentLitlenTable = a;
  for(var e = c.length - Zlib.RawInflate.MaxCopyLength, f, g, h;256 !== (f = this.readCodeByTable(a));) {
    if(256 > f) {
      d >= e && (this.op = d, c = this.expandBuffer(), d = this.op), c[d++] = f
    }else {
      f -= 257;
      h = Zlib.RawInflate.LengthCodeTable[f];
      0 < Zlib.RawInflate.LengthExtraTable[f] && (h += this.readBits(Zlib.RawInflate.LengthExtraTable[f]));
      f = this.readCodeByTable(b);
      g = Zlib.RawInflate.DistCodeTable[f];
      0 < Zlib.RawInflate.DistExtraTable[f] && (g += this.readBits(Zlib.RawInflate.DistExtraTable[f]));
      d >= e && (this.op = d, c = this.expandBuffer(), d = this.op);
      for(;h--;) {
        c[d] = c[d++ - g]
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = d
};
Zlib.RawInflate.prototype.decodeHuffmanAdaptive = function(a, b) {
  var c = this.output, d = this.op;
  this.currentLitlenTable = a;
  for(var e = c.length, f, g, h;256 !== (f = this.readCodeByTable(a));) {
    if(256 > f) {
      d >= e && (c = this.expandBuffer(), e = c.length), c[d++] = f
    }else {
      f -= 257;
      h = Zlib.RawInflate.LengthCodeTable[f];
      0 < Zlib.RawInflate.LengthExtraTable[f] && (h += this.readBits(Zlib.RawInflate.LengthExtraTable[f]));
      f = this.readCodeByTable(b);
      g = Zlib.RawInflate.DistCodeTable[f];
      0 < Zlib.RawInflate.DistExtraTable[f] && (g += this.readBits(Zlib.RawInflate.DistExtraTable[f]));
      d + h > e && (c = this.expandBuffer(), e = c.length);
      for(;h--;) {
        c[d] = c[d++ - g]
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = d
};
Zlib.RawInflate.prototype.expandBuffer = function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.op - Zlib.RawInflate.MaxBackwardLength), b = this.op - Zlib.RawInflate.MaxBackwardLength, c, d, e = this.output;
  if(USE_TYPEDARRAY) {
    a.set(e.subarray(Zlib.RawInflate.MaxBackwardLength, a.length))
  }else {
    c = 0;
    for(d = a.length;c < d;++c) {
      a[c] = e[c + Zlib.RawInflate.MaxBackwardLength]
    }
  }
  this.blocks.push(a);
  this.totalpos += a.length;
  if(USE_TYPEDARRAY) {
    e.set(e.subarray(b, b + Zlib.RawInflate.MaxBackwardLength))
  }else {
    for(c = 0;c < Zlib.RawInflate.MaxBackwardLength;++c) {
      e[c] = e[b + c]
    }
  }
  this.op = Zlib.RawInflate.MaxBackwardLength;
  return e
};
Zlib.RawInflate.prototype.expandBufferAdaptive = function(a) {
  var b = this.input.length / this.ip + 1 | 0, c = this.input, d = this.output;
  a && ("number" === typeof a.fixRatio && (b = a.fixRatio), "number" === typeof a.addRatio && (b += a.addRatio));
  2 > b ? (a = (c.length - this.ip) / this.currentLitlenTable[2], a = 258 * (a / 2) | 0, a = a < d.length ? d.length + a : d.length << 1) : a = d.length * b;
  USE_TYPEDARRAY ? (a = new Uint8Array(a), a.set(d)) : a = d;
  return this.output = a
};
Zlib.RawInflate.prototype.concatBuffer = function() {
  var a = 0, b = this.output, c = this.blocks, d, e = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.totalpos + (this.op - Zlib.RawInflate.MaxBackwardLength)), f, g, h, i;
  if(0 === c.length) {
    return USE_TYPEDARRAY ? this.output.subarray(Zlib.RawInflate.MaxBackwardLength, this.op) : this.output.slice(Zlib.RawInflate.MaxBackwardLength, this.op)
  }
  f = 0;
  for(g = c.length;f < g;++f) {
    d = c[f];
    h = 0;
    for(i = d.length;h < i;++h) {
      e[a++] = d[h]
    }
  }
  f = Zlib.RawInflate.MaxBackwardLength;
  for(g = this.op;f < g;++f) {
    e[a++] = b[f]
  }
  this.blocks = [];
  return this.buffer = e
};
Zlib.RawInflate.prototype.concatBufferDynamic = function() {
  var a, b = this.op;
  USE_TYPEDARRAY ? this.resize ? (a = new Uint8Array(b), a.set(this.output.subarray(0, b))) : a = this.output.subarray(0, b) : (this.output.length > b && (this.output.length = b), a = this.output);
  return this.buffer = a
};
Zlib.Gunzip = function(a) {
  this.input = a;
  this.ip = 0;
  this.member = [];
  this.decompressed = !1
};
Zlib.Gunzip.prototype.getMembers = function() {
  this.decompressed || this.decompress();
  return this.member.slice()
};
Zlib.Gunzip.prototype.decompress = function() {
  for(var a = this.input.length;this.ip < a;) {
    this.decodeMember()
  }
  this.decompressed = !0;
  return this.concatMember()
};
Zlib.Gunzip.prototype.decodeMember = function() {
  var a = new Zlib.GunzipMember, b, c, d, e, f, g = this.input;
  c = this.ip;
  a.id1 = g[c++];
  a.id2 = g[c++];
  if(31 !== a.id1 || 139 !== a.id2) {
    throw Error("invalid file signature:" + a.id1 + "," + a.id2);
  }
  a.cm = g[c++];
  switch(a.cm) {
    case 8:
      break;
    default:
      throw Error("unknown compression method: " + a.cm);
  }
  a.flg = g[c++];
  b = g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24;
  a.mtime = new Date(1E3 * b);
  a.xfl = g[c++];
  a.os = g[c++];
  0 < (a.flg & Zlib.Gzip.FlagsMask.FEXTRA) && (a.xlen = g[c++] | g[c++] << 8, c = this.decodeSubField(c, a.xlen));
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FNAME)) {
    f = [];
    for(e = 0;0 < (b = g[c++]);) {
      f[e++] = String.fromCharCode(b)
    }
    a.name = f.join("")
  }
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FCOMMENT)) {
    f = [];
    for(e = 0;0 < (b = g[c++]);) {
      f[e++] = String.fromCharCode(b)
    }
    a.comment = f.join("")
  }
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FHCRC) && (a.crc16 = Zlib.CRC32.calc(g, 0, c) & 65535, a.crc16 !== (g[c++] | g[c++] << 8))) {
    throw Error("invalid header crc16");
  }
  b = g[g.length - 4] | g[g.length - 3] << 8 | g[g.length - 2] << 16 | g[g.length - 1] << 24;
  g.length - c - 4 - 4 < 512 * b && (d = b);
  c = new Zlib.RawInflate(g, {index:c, bufferSize:d});
  a.data = d = c.decompress();
  c = c.ip;
  a.crc32 = b = (g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24) >>> 0;
  if(Zlib.CRC32.calc(d) !== b) {
    throw Error("invalid CRC-32 checksum: 0x" + Zlib.CRC32.calc(d).toString(16) + " / 0x" + b.toString(16));
  }
  a.isize = b = (g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24) >>> 0;
  if((d.length & 4294967295) !== b) {
    throw Error("invalid input size: " + (d.length & 4294967295) + " / " + b);
  }
  this.member.push(a);
  this.ip = c
};
Zlib.Gunzip.prototype.decodeSubField = function(a, b) {
  return a + b
};
Zlib.Gunzip.prototype.concatMember = function() {
  var a = this.member, b, c, d = 0, e = 0;
  b = 0;
  for(c = a.length;b < c;++b) {
    e += a[b].data.length
  }
  if(USE_TYPEDARRAY) {
    e = new Uint8Array(e);
    for(b = 0;b < c;++b) {
      e.set(a[b].data, d), d += a[b].data.length
    }
  }else {
    e = [];
    for(b = 0;b < c;++b) {
      e[b] = a[b].data
    }
    e = Array.prototype.concat.apply([], e)
  }
  return e
};
var ZLIB_STREAM_RAW_INFLATE_BUFFER_SIZE = 32768;
Zlib.RawInflateStream = function(a, b, c) {
  this.blocks = [];
  this.bufferSize = c ? c : ZLIB_STREAM_RAW_INFLATE_BUFFER_SIZE;
  this.totalpos = 0;
  this.ip = void 0 === b ? 0 : b;
  this.bitsbuflen = this.bitsbuf = 0;
  this.input = USE_TYPEDARRAY ? new Uint8Array(a) : a;
  this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.bufferSize);
  this.op = 0;
  this.resize = this.bfinal = !1;
  this.sp = 0;
  this.status = Zlib.RawInflateStream.Status.INITIALIZED
};
Zlib.RawInflateStream.BlockType = {UNCOMPRESSED:0, FIXED:1, DYNAMIC:2};
Zlib.RawInflateStream.Status = {INITIALIZED:0, BLOCK_HEADER_START:1, BLOCK_HEADER_END:2, BLOCK_BODY_START:3, BLOCK_BODY_END:4, DECODE_BLOCK_START:5, DECODE_BLOCK_END:6};
Zlib.RawInflateStream.prototype.decompress = function(a, b) {
  var c = !1;
  void 0 !== a && (this.input = a);
  void 0 !== b && (this.ip = b);
  for(;!c;) {
    switch(this.status) {
      case Zlib.RawInflateStream.Status.INITIALIZED:
      ;
      case Zlib.RawInflateStream.Status.BLOCK_HEADER_START:
        0 > this.readBlockHeader() && (c = !0);
        break;
      case Zlib.RawInflateStream.Status.BLOCK_HEADER_END:
      ;
      case Zlib.RawInflateStream.Status.BLOCK_BODY_START:
        switch(this.currentBlockType) {
          case Zlib.RawInflateStream.BlockType.UNCOMPRESSED:
            0 > this.readUncompressedBlockHeader() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.FIXED:
            0 > this.parseFixedHuffmanBlock() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.DYNAMIC:
            0 > this.parseDynamicHuffmanBlock() && (c = !0)
        }
        break;
      case Zlib.RawInflateStream.Status.BLOCK_BODY_END:
      ;
      case Zlib.RawInflateStream.Status.DECODE_BLOCK_START:
        switch(this.currentBlockType) {
          case Zlib.RawInflateStream.BlockType.UNCOMPRESSED:
            0 > this.parseUncompressedBlock() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.FIXED:
          ;
          case Zlib.RawInflateStream.BlockType.DYNAMIC:
            0 > this.decodeHuffman() && (c = !0)
        }
        break;
      case Zlib.RawInflateStream.Status.DECODE_BLOCK_END:
        this.bfinal ? c = !0 : this.status = Zlib.RawInflateStream.Status.INITIALIZED
    }
  }
  return this.concatBuffer()
};
Zlib.RawInflateStream.MaxBackwardLength = 32768;
Zlib.RawInflateStream.MaxCopyLength = 258;
Zlib.RawInflateStream.Order = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
Zlib.RawInflateStream.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 258, 258]);
Zlib.RawInflateStream.LengthExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0]);
Zlib.RawInflateStream.DistCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]);
Zlib.RawInflateStream.DistExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
Zlib.RawInflateStream.FixedLiteralLengthTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(288), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 143 >= b ? 8 : 255 >= b ? 9 : 279 >= b ? 7 : 8
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflateStream.FixedDistanceTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(30), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 5
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflateStream.prototype.readBlockHeader = function() {
  var a;
  this.status = Zlib.RawInflateStream.Status.BLOCK_HEADER_START;
  this.save_();
  if(0 > (a = this.readBits(3))) {
    return this.restore_(), -1
  }
  a & 1 && (this.bfinal = !0);
  a >>>= 1;
  switch(a) {
    case 0:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.UNCOMPRESSED;
      break;
    case 1:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.FIXED;
      break;
    case 2:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.DYNAMIC;
      break;
    default:
      throw Error("unknown BTYPE: " + a);
  }
  this.status = Zlib.RawInflateStream.Status.BLOCK_HEADER_END
};
Zlib.RawInflateStream.prototype.readBits = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f;c < a;) {
    f = d[e++];
    if(void 0 === f) {
      return-1
    }
    b |= f << c;
    c += 8
  }
  f = b & (1 << a) - 1;
  this.bitsbuf = b >>> a;
  this.bitsbuflen = c - a;
  this.ip = e;
  return f
};
Zlib.RawInflateStream.prototype.readCodeByTable = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f = a[0], a = a[1], g;c < a;) {
    g = d[e++];
    if(void 0 === g) {
      return-1
    }
    b |= g << c;
    c += 8
  }
  d = f[b & (1 << a) - 1];
  f = d >>> 16;
  this.bitsbuf = b >> f;
  this.bitsbuflen = c - f;
  this.ip = e;
  return d & 65535
};
Zlib.RawInflateStream.prototype.readUncompressedBlockHeader = function() {
  var a, b, c, d = this.input, e = this.ip;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  b = a;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  b |= a << 8;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  c = a;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  if(b === ~(c | a << 8)) {
    throw Error("invalid uncompressed block header: length verify");
  }
  this.bitsbuflen = this.bitsbuf = 0;
  this.ip = e;
  this.blockLength = b;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END
};
Zlib.RawInflateStream.prototype.parseUncompressedBlock = function() {
  var a = this.input, b = this.ip, c = this.output, d = this.op, e = this.blockLength;
  for(this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_START;e--;) {
    d === c.length && (c = this.expandBuffer());
    if(void 0 === a[b]) {
      return this.ip = b, this.op = d, this.blockLength = e + 1, -1
    }
    c[d++] = a[b++]
  }
  0 > e && (this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_END);
  this.ip = b;
  this.op = d;
  return 0
};
Zlib.RawInflateStream.prototype.parseFixedHuffmanBlock = function() {
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  this.litlenTable = Zlib.RawInflateStream.FixedLiteralLengthTable;
  this.distTable = Zlib.RawInflateStream.FixedDistanceTable;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END;
  return 0
};
Zlib.RawInflateStream.prototype.save_ = function() {
  this.ip_ = this.ip;
  this.bitsbuflen_ = this.bitsbuflen;
  this.bitsbuf_ = this.bitsbuf
};
Zlib.RawInflateStream.prototype.restore_ = function() {
  this.ip = this.ip_;
  this.bitsbuflen = this.bitsbuflen_;
  this.bitsbuf = this.bitsbuf_
};
Zlib.RawInflateStream.prototype.parseDynamicHuffmanBlock = function() {
  var a, b, c, d = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflateStream.Order.length), e, f, g, h = 0;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  this.save_();
  a = this.readBits(5) + 257;
  b = this.readBits(5) + 1;
  c = this.readBits(4) + 4;
  if(0 > a || 0 > b || 0 > c) {
    return this.restore_(), -1
  }
  try {
    for(var i = function(a, b, c) {
      for(var d, e, f = 0, f = 0;f < a;) {
        d = this.readCodeByTable(b);
        if(0 > d) {
          throw Error("not enough input");
        }
        switch(d) {
          case 16:
            if(0 > (d = this.readBits(2))) {
              throw Error("not enough input");
            }
            for(d = 3 + d;d--;) {
              c[f++] = e
            }
            break;
          case 17:
            if(0 > (d = this.readBits(3))) {
              throw Error("not enough input");
            }
            for(d = 3 + d;d--;) {
              c[f++] = 0
            }
            e = 0;
            break;
          case 18:
            if(0 > (d = this.readBits(7))) {
              throw Error("not enough input");
            }
            for(d = 11 + d;d--;) {
              c[f++] = 0
            }
            e = 0;
            break;
          default:
            e = c[f++] = d
        }
      }
      return c
    }, j, h = 0;h < c;++h) {
      if(0 > (j = this.readBits(3))) {
        throw Error("not enough input");
      }
      d[Zlib.RawInflateStream.Order[h]] = j
    }
    e = (0,Zlib.Huffman.buildHuffmanTable)(d);
    f = new (USE_TYPEDARRAY ? Uint8Array : Array)(a);
    g = new (USE_TYPEDARRAY ? Uint8Array : Array)(b);
    this.litlenTable = (0,Zlib.Huffman.buildHuffmanTable)(i.call(this, a, e, f));
    this.distTable = (0,Zlib.Huffman.buildHuffmanTable)(i.call(this, b, e, g))
  }catch(l) {
    return this.restore_(), -1
  }
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END;
  return 0
};
Zlib.RawInflateStream.prototype.decodeHuffman = function() {
  var a = this.output, b = this.op, c, d, e, f = this.litlenTable, g = this.distTable, h = a.length;
  for(this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_START;;) {
    this.save_();
    c = this.readCodeByTable(f);
    if(0 > c) {
      return this.op = b, this.restore_(), -1
    }
    if(256 === c) {
      break
    }
    if(256 > c) {
      b === h && (a = this.expandBuffer(), h = a.length), a[b++] = c
    }else {
      d = c - 257;
      e = Zlib.RawInflateStream.LengthCodeTable[d];
      if(0 < Zlib.RawInflateStream.LengthExtraTable[d]) {
        c = this.readBits(Zlib.RawInflateStream.LengthExtraTable[d]);
        if(0 > c) {
          return this.op = b, this.restore_(), -1
        }
        e += c
      }
      c = this.readCodeByTable(g);
      if(0 > c) {
        return this.op = b, this.restore_(), -1
      }
      d = Zlib.RawInflateStream.DistCodeTable[c];
      if(0 < Zlib.RawInflateStream.DistExtraTable[c]) {
        c = this.readBits(Zlib.RawInflateStream.DistExtraTable[c]);
        if(0 > c) {
          return this.op = b, this.restore_(), -1
        }
        d += c
      }
      b + e >= h && (a = this.expandBuffer(), h = a.length);
      for(;e--;) {
        a[b] = a[b++ - d]
      }
      if(this.ip === this.input.length) {
        return this.op = b, -1
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = b;
  this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_END
};
Zlib.RawInflateStream.prototype.expandBuffer = function(a) {
  var b = this.input.length / this.ip + 1 | 0, c = this.input, d = this.output;
  a && ("number" === typeof a.fixRatio && (b = a.fixRatio), "number" === typeof a.addRatio && (b += a.addRatio));
  2 > b ? (a = (c.length - this.ip) / this.litlenTable[2], a = 258 * (a / 2) | 0, a = a < d.length ? d.length + a : d.length << 1) : a = d.length * b;
  USE_TYPEDARRAY ? (a = new Uint8Array(a), a.set(d)) : a = d;
  return this.output = a
};
Zlib.RawInflateStream.prototype.concatBuffer = function() {
  var a, b = this.op;
  this.resize ? USE_TYPEDARRAY ? (a = new Uint8Array(b), a.set(this.output.subarray(this.sp, b))) : a = this.output.slice(this.sp, b) : a = USE_TYPEDARRAY ? this.output.subarray(this.sp, b) : this.output.slice(this.sp, b);
  this.buffer = a;
  this.sp = b;
  return this.buffer
};
Zlib.RawInflateStream.prototype.getBytes = function() {
  return USE_TYPEDARRAY ? this.output.subarray(0, this.op) : this.output.slice(0, this.op)
};
Zlib.InflateStream = function(a) {
  this.input = void 0 === a ? new (USE_TYPEDARRAY ? Uint8Array : Array) : a;
  this.ip = 0;
  this.rawinflate = new Zlib.RawInflateStream(this.input, this.ip);
  this.output = this.rawinflate.output
};
Zlib.InflateStream.prototype.decompress = function(a) {
  if(void 0 !== a) {
    if(USE_TYPEDARRAY) {
      var b = new Uint8Array(this.input.length + a.length);
      b.set(this.input, 0);
      b.set(a, this.input.length);
      this.input = b
    }else {
      this.input = this.input.concat(a)
    }
  }
  if(void 0 === this.method && 0 > this.readHeader()) {
    return new (USE_TYPEDARRAY ? Uint8Array : Array)
  }
  a = this.rawinflate.decompress(this.input, this.ip);
  this.ip = this.rawinflate.ip;
  return a
};
Zlib.InflateStream.prototype.getBytes = function() {
  return this.rawinflate.getBytes()
};
Zlib.InflateStream.prototype.readHeader = function() {
  var a = this.ip, b = this.input, c = b[a++], b = b[a++];
  if(void 0 === c || void 0 === b) {
    return-1
  }
  switch(c & 15) {
    case Zlib.CompressionMethod.DEFLATE:
      this.method = Zlib.CompressionMethod.DEFLATE;
      break;
    default:
      throw Error("unsupported compression method");
  }
  if(0 !== ((c << 8) + b) % 31) {
    throw Error("invalid fcheck flag:" + ((c << 8) + b) % 31);
  }
  if(b & 32) {
    throw Error("fdict flag is not supported");
  }
  this.ip = a
};
Zlib.Util = {};
Zlib.Util.stringToByteArray = function(a) {
  var a = a.split(""), b, c;
  b = 0;
  for(c = a.length;b < c;b++) {
    a[b] = (a[b].charCodeAt(0) & 255) >>> 0
  }
  return a
};
Zlib.Adler32 = function(a) {
  "string" === typeof a && (a = Zlib.Util.stringToByteArray(a));
  return Zlib.Adler32.update(1, a)
};
Zlib.Adler32.update = function(a, b) {
  for(var c = a & 65535, d = a >>> 16 & 65535, e = b.length, f, g = 0;0 < e;) {
    f = e > Zlib.Adler32.OptimizationParameter ? Zlib.Adler32.OptimizationParameter : e;
    e -= f;
    do {
      c += b[g++], d += c
    }while(--f);
    c %= 65521;
    d %= 65521
  }
  return(d << 16 | c) >>> 0
};
Zlib.Adler32.OptimizationParameter = 1024;
Zlib.Deflate = function(a, b) {
  this.input = a;
  this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.Deflate.DefaultBufferSize);
  this.compressionType = Zlib.Deflate.CompressionType.DYNAMIC;
  var c = {}, d;
  if((b || !(b = {})) && "number" === typeof b.compressionType) {
    this.compressionType = b.compressionType
  }
  for(d in b) {
    c[d] = b[d]
  }
  c.outputBuffer = this.output;
  this.rawDeflate = new Zlib.RawDeflate(this.input, c)
};
Zlib.Deflate.DefaultBufferSize = 32768;
Zlib.Deflate.CompressionType = Zlib.RawDeflate.CompressionType;
Zlib.Deflate.compress = function(a, b) {
  return(new Zlib.Deflate(a, b)).compress()
};
Zlib.Deflate.prototype.compress = function() {
  var a, b, c, d = 0;
  c = this.output;
  a = Zlib.CompressionMethod.DEFLATE;
  switch(a) {
    case Zlib.CompressionMethod.DEFLATE:
      b = Math.LOG2E * Math.log(Zlib.RawDeflate.WindowSize) - 8;
      break;
    default:
      throw Error("invalid compression method");
  }
  b = b << 4 | a;
  c[d++] = b;
  switch(a) {
    case Zlib.CompressionMethod.DEFLATE:
      switch(this.compressionType) {
        case Zlib.Deflate.CompressionType.NONE:
          a = 0;
          break;
        case Zlib.Deflate.CompressionType.FIXED:
          a = 1;
          break;
        case Zlib.Deflate.CompressionType.DYNAMIC:
          a = 2;
          break;
        default:
          throw Error("unsupported compression type");
      }
      break;
    default:
      throw Error("invalid compression method");
  }
  a = a << 6 | 0;
  c[d++] = a | 31 - (256 * b + a) % 31;
  b = Zlib.Adler32(this.input);
  this.rawDeflate.op = d;
  c = this.rawDeflate.compress();
  d = c.length;
  USE_TYPEDARRAY && (c = new Uint8Array(c.buffer), c.length <= d + 4 && (this.output = new Uint8Array(c.length + 4), this.output.set(c), c = this.output), c = c.subarray(0, d + 4));
  c[d++] = b >> 24 & 255;
  c[d++] = b >> 16 & 255;
  c[d++] = b >> 8 & 255;
  c[d++] = b & 255;
  return c
};
Zlib.Inflate = function(a, b) {
  var c, d;
  this.input = a;
  this.ip = 0;
  if(b || !(b = {})) {
    b.index && (this.ip = b.index), b.verify && (this.verify = b.verify)
  }
  c = a[this.ip++];
  d = a[this.ip++];
  switch(c & 15) {
    case Zlib.CompressionMethod.DEFLATE:
      this.method = Zlib.CompressionMethod.DEFLATE;
      break;
    default:
      throw Error("unsupported compression method");
  }
  if(0 !== ((c << 8) + d) % 31) {
    throw Error("invalid fcheck flag:" + ((c << 8) + d) % 31);
  }
  if(d & 32) {
    throw Error("fdict flag is not supported");
  }
  this.rawinflate = new Zlib.RawInflate(a, {index:this.ip, bufferSize:b.bufferSize, bufferType:b.bufferType, resize:b.resize})
};
Zlib.Inflate.BufferType = Zlib.RawInflate.BufferType;
Zlib.Inflate.prototype.decompress = function() {
  var a = this.input, b;
  b = this.rawinflate.decompress();
  this.ip = this.rawinflate.ip;
  if(this.verify && (a = (a[this.ip++] << 24 | a[this.ip++] << 16 | a[this.ip++] << 8 | a[this.ip++]) >>> 0, a !== Zlib.Adler32(b))) {
    throw Error("invalid adler-32 checksum");
  }
  return b
};
goog.exportSymbol("Zlib.Inflate", Zlib.Inflate);
goog.exportSymbol("Zlib.Inflate.prototype.decompress", Zlib.Inflate.prototype.decompress);
Zlib.exportObject("Zlib.Inflate.BufferType", {ADAPTIVE:Zlib.Inflate.BufferType.ADAPTIVE, BLOCK:Zlib.Inflate.BufferType.BLOCK});
Zlib.Zip = function(a) {
  a = a || {};
  this.files = [];
  this.comment = a.comment
};
Zlib.Zip.prototype.addFile = function(a, b) {
  var b = b || {}, c, d = a.length, e = 0;
  USE_TYPEDARRAY && a instanceof Array && (a = new Uint8Array(a));
  "number" !== typeof b.compressionMethod && (b.compressionMethod = Zlib.Zip.CompressionMethod.DEFLATE);
  if(b.compress) {
    switch(b.compressionMethod) {
      case Zlib.Zip.CompressionMethod.STORE:
        break;
      case Zlib.Zip.CompressionMethod.DEFLATE:
        e = Zlib.CRC32.calc(a);
        a = this.deflateWithOption(a, b);
        c = !0;
        break;
      default:
        throw Error("unknown compression method:" + b.compressionMethod);
    }
  }
  this.files.push({buffer:a, option:b, compressed:c, size:d, crc32:e})
};
Zlib.Zip.CompressionMethod = {STORE:0, DEFLATE:8};
Zlib.Zip.OperatingSystem = {MSDOS:0, UNIX:3, MACINTOSH:7};
Zlib.Zip.prototype.compress = function() {
  var a = this.files, b, c, d, e, f, g = 0, h = 0, i, j, l, m, k, n;
  k = 0;
  for(n = a.length;k < n;++k) {
    b = a[k];
    l = b.option.filename ? b.option.filename.length : 0;
    m = b.option.comment ? b.option.comment.length : 0;
    if(!b.compressed) {
      switch(b.crc32 = Zlib.CRC32.calc(b.buffer), b.option.compressionMethod) {
        case Zlib.Zip.CompressionMethod.STORE:
          break;
        case Zlib.Zip.CompressionMethod.DEFLATE:
          b.buffer = this.deflateWithOption(b.buffer, b.option);
          b.compressed = !0;
          break;
        default:
          throw Error("unknown compression method:" + b.option.compressionMethod);
      }
    }
    g += 30 + l + b.buffer.length;
    h += 46 + l + m
  }
  c = new (USE_TYPEDARRAY ? Uint8Array : Array)(g + h + (46 + (this.comment ? this.comment.length : 0)));
  d = 0;
  e = g;
  f = e + h;
  k = 0;
  for(n = a.length;k < n;++k) {
    b = a[k];
    l = b.option.filename ? b.option.filename.length : 0;
    m = b.option.comment ? b.option.comment.length : 0;
    i = d;
    c[d++] = c[e++] = 80;
    c[d++] = c[e++] = 75;
    c[d++] = 3;
    c[d++] = 4;
    c[e++] = 1;
    c[e++] = 2;
    c[e++] = 20;
    c[e++] = b.option.os || Zlib.Zip.OperatingSystem.MSDOS;
    c[d++] = c[e++] = 20;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    j = b.option.compressionMethod;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    j = b.option.date || new Date;
    c[d++] = c[e++] = (j.getMinutes() & 7) << 5 | j.getSeconds() / 2 | 0;
    c[d++] = c[e++] = j.getHours() << 3 | j.getMinutes() >> 3;
    c[d++] = c[e++] = (j.getMonth() + 1 & 7) << 5 | j.getDate();
    c[d++] = c[e++] = (j.getFullYear() - 1980 & 127) << 1 | j.getMonth() + 1 >> 3;
    j = b.crc32;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    j = b.buffer.length;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    j = b.size;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    c[d++] = c[e++] = l & 255;
    c[d++] = c[e++] = l >> 8 & 255;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    c[e++] = m & 255;
    c[e++] = m >> 8 & 255;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = i & 255;
    c[e++] = i >> 8 & 255;
    c[e++] = i >> 16 & 255;
    c[e++] = i >> 24 & 255;
    if(j = b.option.filename) {
      if(USE_TYPEDARRAY) {
        c.set(j, d), c.set(j, e), d += l, e += l
      }else {
        for(i = 0;i < l;++i) {
          c[d++] = c[e++] = j[i]
        }
      }
    }
    if(l = b.option.extraField) {
      if(USE_TYPEDARRAY) {
        c.set(l, d), c.set(l, e), d += 0, e += 0
      }else {
        for(i = 0;i < m;++i) {
          c[d++] = c[e++] = l[i]
        }
      }
    }
    if(l = b.option.comment) {
      if(USE_TYPEDARRAY) {
        c.set(l, e), e += m
      }else {
        for(i = 0;i < m;++i) {
          c[e++] = l[i]
        }
      }
    }
    if(USE_TYPEDARRAY) {
      c.set(b.buffer, d), d += b.buffer.length
    }else {
      i = 0;
      for(m = b.buffer.length;i < m;++i) {
        c[d++] = b.buffer[i]
      }
    }
  }
  c[f++] = 80;
  c[f++] = 75;
  c[f++] = 5;
  c[f++] = 6;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = n & 255;
  c[f++] = n >> 8 & 255;
  c[f++] = n & 255;
  c[f++] = n >> 8 & 255;
  c[f++] = h & 255;
  c[f++] = h >> 8 & 255;
  c[f++] = h >> 16 & 255;
  c[f++] = h >> 24 & 255;
  c[f++] = g & 255;
  c[f++] = g >> 8 & 255;
  c[f++] = g >> 16 & 255;
  c[f++] = g >> 24 & 255;
  m = this.comment ? this.comment.length : 0;
  c[f++] = m & 255;
  c[f++] = m >> 8 & 255;
  if(this.comment) {
    if(USE_TYPEDARRAY) {
      c.set(this.comment, f)
    }else {
      for(i = 0;i < m;++i) {
        c[f++] = this.comment[i]
      }
    }
  }
  return c
};
Zlib.Zip.prototype.deflateWithOption = function(a, b) {
  return(new Zlib.RawDeflate(a, b.deflateOption)).compress()
};
Zlib.Unzip = function(a, b) {
  b = b || {};
  this.input = USE_TYPEDARRAY && a instanceof Array ? new Uint8Array(a) : a;
  this.ip = 0;
  this.verify = b.verify || !1
};
Zlib.Unzip.CompressionMethod = Zlib.Zip.CompressionMethod;
Zlib.Unzip.FileHeader = function(a, b) {
  this.input = a;
  this.offset = b
};
Zlib.Unzip.FileHeader.prototype.parse = function() {
  var a = this.input, b = this.offset;
  if(80 !== a[b++] || 75 !== a[b++] || 1 !== a[b++] || 2 !== a[b++]) {
    throw Error("invalid file header signature");
  }
  this.version = a[b++];
  this.os = a[b++];
  this.needVersion = a[b++] | a[b++] << 8;
  this.flags = a[b++] | a[b++] << 8;
  this.compression = a[b++] | a[b++] << 8;
  this.time = a[b++] | a[b++] << 8;
  this.date = a[b++] | a[b++] << 8;
  this.crc32 = (a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24) >>> 0;
  this.compressedSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.plainSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.fileNameLength = a[b++] | a[b++] << 8;
  this.extraFieldLength = a[b++] | a[b++] << 8;
  this.fileCommentLength = a[b++] | a[b++] << 8;
  this.diskNumberStart = a[b++] | a[b++] << 8;
  this.internalFileAttributes = a[b++] | a[b++] << 8;
  this.externalFileAttributes = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.relativeOffset = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.filename = String.fromCharCode.apply(null, USE_TYPEDARRAY ? a.subarray(b, b += this.fileNameLength) : a.slice(b, b += this.fileNameLength));
  this.extraField = USE_TYPEDARRAY ? a.subarray(b, b += this.extraFieldLength) : a.slice(b, b += this.extraFieldLength);
  this.comment = USE_TYPEDARRAY ? a.subarray(b, b + this.fileCommentLength) : a.slice(b, b + this.fileCommentLength);
  this.length = b - this.offset
};
Zlib.Unzip.LocalFileHeader = function(a, b) {
  this.input = a;
  this.offset = b
};
Zlib.Unzip.LocalFileHeader.prototype.parse = function() {
  var a = this.input, b = this.offset;
  if(80 !== a[b++] || 75 !== a[b++] || 3 !== a[b++] || 4 !== a[b++]) {
    throw Error("invalid local file header signature");
  }
  this.needVersion = a[b++] | a[b++] << 8;
  this.flags = a[b++] | a[b++] << 8;
  this.compression = a[b++] | a[b++] << 8;
  this.time = a[b++] | a[b++] << 8;
  this.date = a[b++] | a[b++] << 8;
  this.crc32 = (a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24) >>> 0;
  this.compressedSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.plainSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.fileNameLength = a[b++] | a[b++] << 8;
  this.extraFieldLength = a[b++] | a[b++] << 8;
  this.filename = String.fromCharCode.apply(null, USE_TYPEDARRAY ? a.subarray(b, b += this.fileNameLength) : a.slice(b, b += this.fileNameLength));
  this.extraField = USE_TYPEDARRAY ? a.subarray(b, b += this.extraFieldLength) : a.slice(b, b += this.extraFieldLength);
  this.length = b - this.offset
};
Zlib.Unzip.prototype.searchEndOfCentralDirectoryRecord = function() {
  var a = this.input, b;
  for(b = a.length - 12;0 < b;--b) {
    if(80 === a[b] && 75 === a[b + 1] && 5 === a[b + 2] && 6 === a[b + 3]) {
      this.eocdrOffset = b;
      return
    }
  }
  throw Error("End of Central Directory Record not found");
};
Zlib.Unzip.prototype.parseEndOfCentralDirectoryRecord = function() {
  var a = this.input, b;
  this.eocdrOffset || this.searchEndOfCentralDirectoryRecord();
  b = this.eocdrOffset;
  if(80 !== a[b++] || 75 !== a[b++] || 5 !== a[b++] || 6 !== a[b++]) {
    throw Error("invalid signature");
  }
  this.numberOfThisDisk = a[b++] | a[b++] << 8;
  this.startDisk = a[b++] | a[b++] << 8;
  this.totalEntriesThisDisk = a[b++] | a[b++] << 8;
  this.totalEntries = a[b++] | a[b++] << 8;
  this.centralDirectorySize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.centralDirectoryOffset = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.commentLength = a[b++] | a[b++] << 8;
  this.comment = USE_TYPEDARRAY ? a.subarray(b, b + this.commentLength) : a.slice(b, b + this.commentLength)
};
Zlib.Unzip.prototype.parseFileHeader = function() {
  var a = [], b = {}, c, d, e, f;
  if(!this.fileHeaderList) {
    void 0 === this.centralDirectoryOffset && this.parseEndOfCentralDirectoryRecord();
    c = this.centralDirectoryOffset;
    e = 0;
    for(f = this.totalEntries;e < f;++e) {
      d = new Zlib.Unzip.FileHeader(this.input, c), d.parse(), c += d.length, a[e] = d, b[d.filename] = e
    }
    if(this.centralDirectorySize < c - this.centralDirectoryOffset) {
      throw Error("invalid file header size");
    }
    this.fileHeaderList = a;
    this.filenameToIndex = b
  }
};
Zlib.Unzip.prototype.getFileData = function(a) {
  var b = this.fileHeaderList, c;
  b || this.parseFileHeader();
  if(void 0 === b[a]) {
    throw Error("wrong index");
  }
  b = b[a].relativeOffset;
  a = new Zlib.Unzip.LocalFileHeader(this.input, b);
  a.parse();
  b += a.length;
  c = a.compressedSize;
  switch(a.compression) {
    case Zlib.Unzip.CompressionMethod.STORE:
      b = USE_TYPEDARRAY ? this.input.subarray(b, b + c) : this.input.slice(b, b + c);
      break;
    case Zlib.Unzip.CompressionMethod.DEFLATE:
      b = (new Zlib.RawInflate(this.input, {index:b, bufferSize:a.plainSize})).decompress();
      break;
    default:
      throw Error("unknown compression type");
  }
  if(this.verify && (c = Zlib.CRC32.calc(b), a.crc32 !== c)) {
    throw Error("wrong crc: file=0x" + a.crc32.toString(16) + ", data=0x" + c.toString(16));
  }
  return b
};
Zlib.Unzip.prototype.getFilenames = function() {
  var a = [], b, c, d;
  this.fileHeaderList || this.parseFileHeader();
  d = this.fileHeaderList;
  b = 0;
  for(c = d.length;b < c;++b) {
    a[b] = d[b].filename
  }
  return a
};
Zlib.Unzip.prototype.decompress = function(a) {
  var b;
  this.filenameToIndex || this.parseFileHeader();
  b = this.filenameToIndex[a];
  if(void 0 === b) {
    throw Error(a + " not found");
  }
  return this.getFileData(b)
};
Zlib.CompressionMethod = {DEFLATE:8, RESERVED:15};
}).call(this);
