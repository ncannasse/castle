/*
 * Copyright (c) 2015, Nicolas Cannasse
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
package cdb;
import cdb.Data;

class TileBuilder {

	/*

		Bits

		1	2	4
		8	X	16
		32	64	128

		Corners

		┌  ─  ┐		0 1 2
		│  ■  │		3 8 4
		└  ─  ┘		5 6 7

		Lower Corners

		┌ ┐		9  10
		└ ┘		11 12

		U Corners

		   ┌ ┐			XX  13  XX
		┌       ┐		14  XX  15
		└       ┘
		   └ ┘			XX  16  XX

		Bottom

		└ - ┘			17 18 19


	*/


	var groundMap : Array<Int>;
	var groundIds = new Map<String, { id : Int, fill : Array<Int> }>();
	var borders = new Array<Array<Array<Int>>>();

	public function new( t : TilesetProps, stride : Int, total : Int ) {
		groundMap = [];
		for( i in 0...total+1 )
			groundMap[i] = 0;
		groundMap[0] = 0;
		borders = [];

		// get all grounds
		var tmp = new Map();
		for( s in t.sets )
			switch( s.t ) {
			case Ground if( s.opts.name != "" && s.opts.name != null ):
				var g = tmp.get(s.opts.name);
				if( g == null ) {
					g = [];
					tmp.set(s.opts.name, g);
				}
				g.push(s);
			default:
			}

		// sort by priority
		var allGrounds = Lambda.array(tmp);
		inline function ifNull<T>(v:Null<T>, def:T) return v == null ? def : v;
		allGrounds.sort(function(g1, g2) {
			var dp = ifNull(g1[0].opts.priority,0) - ifNull(g2[0].opts.priority,0);
			return dp != 0 ? dp : Reflect.compare(g1[0].opts.name, g2[0].opts.name);
		});

		// allocate group id
		var gid = 0;
		for( g in allGrounds ) {
			var p = ifNull(g[0].opts.priority, 0);
			if( p > 0 ) gid++;
			var fill = [];
			for( s in g )
				for( dx in 0...s.w )
					for( dy in 0...s.h ) {
						var tid = s.x + dx + (s.y + dy) * stride;
						fill.push(tid);
						groundMap[tid + 1] = gid;
					}
			groundIds.set(g[0].opts.name, { id : gid, fill : fill });
		}
		var maxGid = gid + 1;

		// save borders combos
		var allBorders = [];
		for( s in t.sets )
			if( s.t == Border )
				allBorders.push(s);
		inline function bweight(b) {
			var k = 0;
			if( b.opts.borderIn != null ) k += 1;
			if( b.opts.borderOut != null ) k += 2;
			if( b.opts.borderMode != null ) k += 4;
			if( b.opts.borderIn != null && b.opts.borderOut != null && b.opts.borderIn != "lower" && b.opts.borderOut != "upper" ) k += 8;
			return k;
		}
		allBorders.sort(function(b1, b2) {
			return bweight(b1) - bweight(b2);
		});
		for( b in allBorders ) {
			var gid = b.opts.borderIn == null ? null : groundIds.get(b.opts.borderIn);
			var tid = b.opts.borderOut == null ? null : groundIds.get(b.opts.borderOut);
			if( gid == null && tid == null ) continue;
			var gids, tids;
			if( gid != null )
				gids = [gid.id];
			else {
				switch( b.opts.borderIn ) {
				case null: gids = [for( g in tid.id + 1...maxGid ) g];
				case "lower": gids = [for( g in 0...tid.id ) g];
				default: continue;
				}
			}
			if( tid != null )
				tids = [tid.id];
			else {
				switch( b.opts.borderOut ) {
				case null: tids = [for( g in 0...gid.id ) g];
				case "upper": tids = [for( g in gid.id + 1...maxGid ) g];
				default: continue;
				}
			}
			var clear = gid != null && tid != null && b.opts.borderMode == null;
			switch( b.opts.borderMode ) {
			case "corner":
				// swap
				var tmp = gids;
				gids = tids;
				tids = tmp;
			default:
			}
			for( g in gids )
				for( t in tids ) {
					var bt = borders[g + t * 256];
					if( bt == null || clear ) {
						bt = [for( i in 0...20 ) []];
						if( gid != null ) bt[8] = gid.fill;
						borders[g + t * 256] = bt;
					}
					for( dx in 0...b.w )
						for( dy in 0...b.h ) {
							var k;
							switch( b.opts.borderMode ) {
							case null:
								if( dy == 0 )
									k = dx == 0 ? 0 : dx == b.w - 1 ? 2 : 1;
								else if( dy == b.h - 1 )
									k = dx == 0 ? 5 : dx == b.w - 1 ? 7 : 6;
								else if( dx == 0 )
									k = 3;
								else if( dx == b.w - 1 )
									k = 4;
								else
									continue;
							case "corner":
								if( dx == 0 && dy == 0 )
									k = 9;
								else if( dx == b.w - 1 && dy == 0 )
									k = 10;
								else if( dx == 0 && dy == b.h - 1 )
									k = 11;
								else if( dx == b.w - 1 && dy == b.h - 1 )
									k = 12;
								else
									continue;
							case "u":
								if( dx == 1 && dy == 0 )
									k = 13;
								else if( dx == 0 && dy == 1 )
									k = 14;
								else if( dx == 2 && dy == 1 )
									k = 15;
								else if( dx == 1 && dy == 2 )
									k = 16;
								else
									continue;
							case "bottom":
								k = dx == 0 ? 17 : dx == b.w - 1 ? 19 : 18;
							default:
								continue;
							}
							bt[k].push(b.x + dx + (b.y + dy) * stride);
						}
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
				var g = groundMap[v];
				var gl = x == 0 ? g : groundMap[input[p - 1]];
				var gr = x == width - 1 ? g : groundMap[input[p + 1]];
				var gt = y == 0 ? g : groundMap[input[p - width]];
				var gb = y == height - 1 ? g : groundMap[input[p + width]];

				var gtl = x == 0 || y == 0 ? g : groundMap[input[p - 1 - width]];
				var gtr = x == width - 1 || y == 0 ? g : groundMap[input[p + 1 - width]];
				var gbl = x == 0 || y == height-1 ? g : groundMap[input[p - 1 + width]];
				var gbr = x == width - 1 || y == height - 1 ? g : groundMap[input[p + 1 + width]];

				inline function max(a, b) return a > b ? a : b;
				inline function min(a, b) return a > b ? b : a;
				var max = max(max(max(gr, gl), max(gt, gb)), max(max(gtr, gtl), max(gbr, gbl)));
				var min = min(min(min(gr, gl), min(gt, gb)), min(min(gtr, gtl), min(gbr, gbl)));

				for( t in min...max + 1 ) {
					var bb = borders[t + g * 256];

					if( bb == null ) continue;

					var bits = 0;
					if( t == gtl )
						bits |= 1;
					if( t == gt )
						bits |= 2;
					if( t == gtr )
						bits |= 4;
					if( t == gl )
						bits |= 8;
					if( t == gr )
						bits |= 16;
					if( t == gbl )
						bits |= 32;
					if( t == gb )
						bits |= 64;
					if( t == gbr )
						bits |= 128;

					inline function addTo( x : Int, y : Int, a : Array<Int> ) {
						out.push(x);
						out.push(y);
						out.push(a.length == 1 ? a[0] : a[random(x + y * width) % a.length]);
					}

					inline function add( a : Array<Int> ) {
						addTo(x, y, a);
					}

					inline function check( b, clear, k ) {
						var f = false;
						if( bits & b == b ) {
							var a = bb[k];
							if( a.length != 0 ) {
								bits &= ~(clear | b);
								add(a);
								f = true;
							}
						}
						return f;
					}

					check(2 | 8 | 16, 1 | 4, 13);
					check(2 | 8 | 64, 1 | 32, 14);
					check(2 | 16 | 64, 4 | 128, 15);
					check(8 | 16 | 64, 32 | 128, 16);

					check(2 | 8, 1 | 4 | 32, 9);
					check(2 | 16, 1 | 4 | 128, 10);
					check(8 | 64, 1 | 32 | 128, 11);
					check(16 | 64, 4 | 32 | 128, 12);

					if( check(2, 1 | 4, 6) ) {
						var a = bb[18];
						if( a.length != 0 ) {
							out.push(x);
							out.push(y + 1);
							if( x > 0 && y > 0 && groundMap[input[p - 1 - width]] != t )
								out.push(a[0]);
							else if( x < width - 1 && y > 0 && groundMap[input[p + 1 - width]] != t )
								out.push(a[a.length - 1]);
							else if( a.length == 1 )
								out.push(a[0]);
							else
								out.push(a[1 + random(x + y * width) % (a.length - 2)]);
						}
					}
					check(8, 1 | 32, 4);
					check(16, 4 | 128, 3);
					check(64, 32 | 128, 1);

					if( check(1, 1, 7) ) {
						var a = bb[19];
						if( a.length != 0 )
							addTo(x, y + 1, a);
					}
					if( check(4, 4, 5) ) {
						var a = bb[17];
						if( a.length != 0 )
							addTo(x, y + 1, a);
					}
					check(32, 32, 2);
					check(128, 128, 0);
				}
			}
		return out;
	}

}