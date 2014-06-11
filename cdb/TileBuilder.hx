package cdb;
import cdb.Data;

class TileBuilder {

	var grounds : Array<Int>;
	var groundIds = new Map<String, Int>();
	var borders = new Array<Array<Array<Int>>>();

	public function new( t : TileProps, stride : Int, total : Int ) {
		grounds = [];
		for( i in 0...total+1 )
			grounds[i] = 0;
		grounds[0] = -1;
		borders = [];
		for( s in t.sets )
			switch( s.t ) {
			case Tile:
				// nothing
			case Ground:
				var gid = s.opts.priority;
				if( gid == null ) gid = 0;
				gid++;
				var bl = [for( i in 0...16 ) []];
				borders[gid] = bl;
				for( dx in 0...s.w )
					for( dy in 0...s.h ) {
						var tid = s.x + dx + (s.y + dy) * stride + 1;
						bl[15].push(tid - 1);
						grounds[tid] = gid;
					}
				groundIds.set(s.opts.name, gid);
			case Object:
			case Border:
			}
		for( s in t.sets )
			if( s.t == Border ) {
				var gid = groundIds.get(s.opts.border);
				if( gid == null ) continue;
				var bt = borders[gid];
				if( bt == null ) continue;
				for( dx in 0...s.w )
					for( dy in 0...s.h ) {
						var k;
						if( s.opts.borderOut ) {
							if( dx == 0 && dy == 0 )
								k = 14;
							else if( dx == s.w - 1 && dy == 0 )
								k = 13;
							else if( dx == 0 && dy == s.h - 1 )
								k = 11;
							else if( dx == s.w - 1 && dy == s.h - 1 )
								k = 7;
							else
								continue;
						} else {
							if( dy == 0 )
								k = dx == 0 ? 1 : dx == s.w - 1 ? 2 : 3;
							else if( dy == s.h - 1 )
								k = dx == 0 ? 4 : dx == s.w - 1 ? 8 : 12;
							else if( dx == 0 )
								k = 5;
							else if( dx == s.w - 1 )
								k = 10;
							else
								continue;
						}
						bt[k].push(s.x + dx + (s.y + dy) * stride);
					}
			}
	}

	function random( n : Int ) {
		n *= 0xcc9e2d51;
		n = (n << 15) | (n >>> 17);
		n *= 0x1b873593;
		var h = 5381;
		h ^= n;
		h = (h << 13) | (h >>> 19);
		h = h*5 + 0xe6546b64;
		h ^= h >> 16;
		h *= 0x85ebca6b;
		h ^= h >> 13;
		h *= 0xc2b2ae35;
		h ^= h >> 16;
		return h;
	}

	/**
		Returns [X,Y,TileID] sets
	**/
	public function buildGrounds( input : Array<Int>, width : Int ) : Array<Int> {
		var height = Std.int(input.length / width);
		var p = -1;
		var out = [];
		for( y in 0...height )
			for( x in 0...width ) {
				var v = input[++p];
				var g = grounds[v];
				var gl = x == 0 ? g : grounds[input[p - 1]];
				var gr = x == width - 1 ? g : grounds[input[p + 1]];
				var gt = y == 0 ? g : grounds[input[p - width]];
				var gd = y == height - 1 ? g : grounds[input[p + width]];

				var gtl = x == 0 || y == 0 ? g : grounds[input[p - 1 - width]];
				var gtr = x == width - 1 || y == 0 ? g : grounds[input[p + 1 - width]];
				var gbl = x == 0 || y == height-1 ? g : grounds[input[p - 1 + width]];
				var gbr = x == width - 1 || y == height - 1 ? g : grounds[input[p + 1 + width]];

				inline function max(a, b) return a > b ? a : b;
				inline function min(a, b) {
					if( a <= g ) a = 1000;
					if( b <= g ) b = 1000;
					return a > b ? b : a;
				}
				var max = max(max(max(gr, gl), max(gt, gd)), max(max(gtr, gtl), max(gbr, gbl)));
				var min = min(min(min(gr, gl), min(gt, gd)), min(min(gtr, gtl), min(gbr, gbl)));

				for( g in min-1...max ) {
					var bits = 0;
					if( g < gl )
						bits |= 8 | 2;
					if( g < gr )
						bits |= 4 | 1;
					if( g < gt )
						bits |= 8 | 4;
					if( g < gd )
						bits |= 2 | 1;
					if( g < gtl )
						bits |= 8;
					if( g < gtr )
						bits |= 4;
					if( g < gbl )
						bits |= 2;
					if( g < gbr )
						bits |= 1;
					if( bits == 0 )
						continue;
					var bb = borders[g+1];
					if( bb == null ) continue;
					var a = bb[bits];
					if( a.length == 0 ) {
						switch( bits ) {
						case 7, 11, 13, 14:
							// fallback for out corners
							a = bb[15];
						case 6:
							// fallback for diagonal
							a = bb[2];
							if( a.length > 0 ) {
								out.push(x);
								out.push(y);
								out.push(a.length == 1 ? a[0] : a[random(x + y * width) % a.length]);
							}
							a = bb[4];
						case 9:
							// fallback for diagonal
							a = bb[1];
							if( a.length > 0 ) {
								out.push(x);
								out.push(y);
								out.push(a.length == 1 ? a[0] : a[random(x + y * width) % a.length]);
							}
							a = bb[8];
						default:
							continue;
						}
						if( a.length == 0 )
							continue;
					}
					out.push(x);
					out.push(y);
					out.push(a.length == 1 ? a[0] : a[random(x + y * width) % a.length]);
				}
			}
		return out;
	}

}