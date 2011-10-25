var // Dependency References
    fs = require( "fs" ),
    _ = require( "underscore" ),
    jshint = require( "jshint" ).JSHINT,
    colors = require( "colors" ),
    uglifyjs = require( "uglify-js" ),
    Buffer = require( "buffer" ).Buffer,
    zlib = require( "zlib" ),
    dateFormat = require( "dateformat" ),
    stats = require( "stats" ),
    cp = require("child_process"),
    exec = cp.exec,
    spawn = cp.spawn,
    assert = require("assert"),
    child;

var // Shortcut References
    slice = Array.prototype.slice,
    now = new Date();

var // Program References
    $$ = {},
    // Get options, defaults merged with build.json file.
    config = _.extend({}, true, {

        // Meta Build Info
        "meta": {
          "buildDate": dateFormat( now, "m/d/yyyy" )
        },

        // Overridden with build.json
        "files": {},

        // License Banner Template
        "banner": [
          "// <%= label %> - v<%= version %> - <%= buildDate %>",
          "// <%= homeurl %>",
          "// <%= copyright %>; Licensed <%= license.join(', ') %>"
        ].join( "\n" ),

        // JSHint Optional Settings
        "jshint": {
          unused: true,
          unuseds: true,
          devel: true,
          undef: true,
          noempty: true,
          evil: true,
          forin: false,
          maxerr: 100,
          loopfunc: true,
          eqnull: true,
          jquery: true
        },

        // Uglify Optional Settings
        "uglify": {
          "mangle": {
            "except": [ "$" ]
          },
          "squeeze": {},
          "codegen": {}
        }
      },
      readJson( "build.json", true )
    ),
    // Setup Distribution File Banner (License Block)
    banner = _.template( typeof config.banner == "string" ? config.banner : "" );

// Logging Utility Functions
function header( msg ) {
  writeln( "\n" + msg.underline );
}
function write( msg ) {
  process.stdout.write( (msg != null && msg) || "" );
}
function writeln( msg ) {
  console.log( (msg != null && msg) || "" );
}
function ok( msg ) {
  writeln( msg ? "\n>> ".green + msg : "OK".green );
}
function error( msg ) {
  writeln( msg ? "\n>> ".red + msg : "ERROR".red );
}


// Read a file.
function readFile( filepath ) {
  var src;
  write( "Reading " + filepath + "..." );
  try {
    src = fs.readFileSync( filepath, "UTF-8" );
    ok();
    return src;
  } catch( e ) {
    error();
    fail( e.message );
  }
}

// Write a file.
function writeFile( filepath, contents, silent ) {
  // if ( config.nowrite ) {
  //   writeln('Not'.underline + ' writing ' + filepath + ' (dry run).');
  //   return true;
  // }

  if ( arguments.length < 3 ) {
    silent = true;
  }

  silent || write( "Writing " + filepath + "..." );

  try {
    fs.writeFileSync( filepath, contents, "UTF-8" );
  } catch( e ) {
    error();
    fail( e );
  }

  ok();
  return true;
}

// Read and parse a JSON file.
function readJson( filepath, silent ) {
  var result;

  silent || write( "Reading " + filepath + "..." );

  try {
    result = JSON.parse(
      fs.readFileSync( filepath, "UTF-8" )
    );
  } catch( e ) {
    silent || error();
    fail( e.message );
  }

  silent || ok();
  return result;
}


// # Lint some source code.
// From http://jshint.com
function hint( src, path ) {
  write( "Validating with JSHint...");

  if ( jshint( src, config.jshint ) ) {
    ok();
  } else {
    error();

    jshint.errors.forEach(function( e ) {
      if ( !e ) { return; }
      var str = e.evidence ? e.evidence.inverse : "";

      str = str.replace( /\t/g, " " ).trim();
      error( path + " [L" + e.line + ":C" + e.character + "] " + e.reason + "\n  " + str );
    });
    fail( "JSHint found errors." );
  }
}

// # Minify with UglifyJS.
// From https://github.com/mishoo/UglifyJS
function uglify( src ) {
  write( "Uglifying..." );

  var jsp = uglifyjs.parser,
      pro = uglifyjs.uglify,
      ast;

  try {
    ast = jsp.parse( src );
    ast = pro.ast_mangle( ast, config.uglify.mangle || {});
    ast = pro.ast_squeeze( ast, config.uglify.squeeze || {});
    src = pro.gen_code( ast, config.uglify.codegen || {});

  } catch( e ) {
    error();
    error( "[L" + e.line + ":C" + e.col + "] " + e.message + " (position: " + e.pos + ")" );
    fail( e.message );
    return false;
  }

  ok();
  return src;
}

// Return deflated src input.
function gzip( src ) {
  return zlib.deflate( new Buffer( src ) );
}

// Jake Tasks

desc( "Hint & Minify" );
task( "default", [ "hint", "min" ], function() {
  // Nothing
});

desc( "Validate with JSHint." );
task( "hint", function() {

  header( "Validating with JSHint" );

  _.keys( config.files ).forEach(function( minpath ) {

    var files = config.files[ minpath ],
        concat = files.src.map(function( path ) {
          var src = readFile( path );

          config.jshint.devel = config.jshint.debug = files.debug;

          if ( files.prehint ) {
            hint( src, path );
          }

          return src;
        }).join( "\n" );

    if ( files.src.length ) {
      write( "Hnting concatenated source: " + files.src.length + " scripts..." );
      ok();
      if ( files.posthint ) {
        hint( concat, "post" );
      }
    }
  });
});

desc( "Minify with Uglify-js." );
task( "min", function() {

  header( "Minifying with Uglify-js" );

  _.keys( config.files ).forEach(function( minpath ) {

    var file = config.files[ minpath ],
        concat = file.src.map( function( path ) {
          return readFile( path );
        }).join( "\n" ),

        intro, fullpath, min;


    fullpath = minpath + ".js";
    minpath = minpath + ".min.js"

    // Generate intro block with banner template,
    // Inject meta build data
    intro = banner( _.extend( file.meta, config.meta ) );

    // Without a newline, the min source code will run on the same
    // Line as the intro lic/banner block
    if ( intro ) {
      intro += "\n";
    }

    // Provide information about current file being built
    if ( file.src.length ) {
      write( "Concatenating " + file.src.length + " script(s)" );
      ok();
    }

    // Write full sized, concatenated source
    writeFile( fullpath, concat, false );

    // Minify/Uglify and Write compressed, concatenated source
    if ( min = uglify( concat ) ) {

      min = intro + min;

      if ( writeFile( minpath, min, false ) ) {
        ok( "Compressed size: " + (gzip( min ).length + "").yellow + " bytes gzipped (" + ( min.length + "" ).yellow + " bytes minified)." );
      }
    }
  });
});

