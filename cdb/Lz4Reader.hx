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

#if lz4js
@:native("lz4")
extern class Lz4js {
	#if (haxe_ver < 4)
	public static function compress( source : js.html.Uint8Array, blockSize : Int ) : js.html.Uint8Array;
	public static function decompress( source : js.html.Uint8Array ) : js.html.Uint8Array;
	#else
	public static function compress( source : js.lib.Uint8Array, blockSize : Int ) : js.lib.Uint8Array;
	public static function decompress( source : js.lib.Uint8Array ) : js.lib.Uint8Array;
	#end
}
#end

class Lz4Reader {

	var bytes : haxe.io.Bytes;
	var pos : Int;

	public function new() {
	}

	inline function b() {
		return bytes.get(pos++);
	}

	function grow( out : haxe.io.Bytes, pos : Int, len : Int ) {
		var size = out.length;
		do {
			size = (size * 3) >> 1;
		} while( size < pos + len );
		var out2 = haxe.io.Bytes.alloc(size);
		out2.blit(0, out, 0, pos);
		return out2;
	}

	public function read( bytes : haxe.io.Bytes ) : haxe.io.Bytes {
		this.bytes = bytes;
		this.pos = 0;
		if( b() != 0x04 || b() != 0x22 || b() != 0x4D || b() != 0x18 )
			throw "Invalid header";
		var flags = b();

		if( flags >> 6 != 1 )
			throw "Invalid version " + (flags >> 6);
		var blockChecksum = flags & 16 != 0;
		var streamSize = flags & 8 != 0;
		var streamChecksum = flags & 4 != 0;
		if( flags & 2 != 0 ) throw "assert";
		var presetDict = flags & 1 != 0;

		var bd = b();
		if( bd & 128 != 0 ) throw "assert";
		var maxBlockSize = [0, 0, 0, 0, 1 << 16, 1 << 18, 1 << 20, 1 << 22][(bd >> 4) & 7];
		if( maxBlockSize == 0 ) throw "assert";
		if( bd & 15 != 0 ) throw "assert";

		if( streamSize )
			pos += 8;
		if( presetDict )
			throw "Preset dictionary not supported";

		var headerChk = b(); // does not check

		var out = haxe.io.Bytes.alloc(128);
		var outPos = 0;

		while( true ) {
			var size = b() | (b() << 8) | (b() << 16) | (b() << 24);
			if( size == 0 ) break;
			// skippable chunk
			if( size & 0xFFFFFFF0 == 0x184D2A50 ) {
				var dataSize = b() | (b() << 8) | (b() << 16) | (b() << 24);
				pos += dataSize;
				continue;
			}
			if( size & 0x80000000 != 0 ) {
				// uncompressed block
				size &= 0x7FFFFFFF;
				if( outPos + out.length < size ) out = grow(out, outPos, size);
				out.blit(outPos, bytes, pos, size);
				outPos += size;
				pos += size;
			} else {
				var srcEnd = pos + size;
				while( pos < srcEnd ) {
					var r = uncompress(bytes, pos, srcEnd - pos, out, outPos);
					pos = r[0];
					outPos = r[1];
					var req = r[2];
					if( req > 0 )
						out = grow(out, outPos, req);
				}
			}
			if( blockChecksum ) pos += 4;
		}

		return out.sub(0, outPos);
	}

	public static function uncompress( src : haxe.io.Bytes, srcPos : Int, srcLen : Int, out : haxe.io.Bytes, outPos : Int ) {
		var outSave = outPos;
		var srcEnd = srcPos + srcLen;
		if( srcLen == 0 )
			return [srcPos,outPos, 0];
		var outLen = out.length;
		#if flash
		var outd = out.getData();
		if( outd.length < 1024 ) outd.length = 1024;
		flash.Memory.select(outd);
		#end
		while( true ) {
			var start = srcPos;
			var tk = src.get(srcPos++);
			var litLen = tk >> 4;
			var matchLen = tk & 15;
			if( litLen == 15 ) {
				var b;
				do {
					b = src.get(srcPos++);
					litLen += b;
				} while( b == 0xFF );
			}
			inline function write(v) {
				#if flash
				flash.Memory.setByte(outPos, v);
				#else
				out.set(outPos, v);
				#end
				outPos++;
			}
			if( outPos + litLen > outLen )
				return [start, outPos, litLen + matchLen];

			switch( litLen ) {
			case 0:
			case 1:
				write(src.get(srcPos++));
			case 2:
				write(src.get(srcPos++));
				write(src.get(srcPos++));
			case 3:
				write(src.get(srcPos++));
				write(src.get(srcPos++));
				write(src.get(srcPos++));
			default:
				out.blit(outPos, src, srcPos, litLen);
				outPos += litLen;
				srcPos += litLen;
			}
			if( srcPos >= srcEnd ) break;
			var offset = src.get(srcPos++);
			offset |= src.get(srcPos++) << 8;
			if( matchLen == 15 ) {
				var b;
				do {
					b = src.get(srcPos++);
					matchLen += b;
				} while( b == 0xFF );
			}
			matchLen += 4;

			if( outPos + matchLen > outLen )
				return [start, outPos - litLen, litLen + matchLen];

			if( matchLen >= 64 && matchLen <= offset ) {
				out.blit(outPos, out, outPos - offset, matchLen);
				outPos += matchLen;
			} else {
				var copyEnd = outPos + matchLen;
				while( outPos < copyEnd )
					write(#if flash flash.Memory.getByte(outPos - offset) #else out.get(outPos - offset) #end);
			}
		}
		if( srcPos != srcEnd ) throw "Read too much data " + (srcPos - srcLen);
		return [srcPos, outPos, 0];
	}

	public static function decodeString( s : String ) : haxe.io.Bytes {
		if( s == "" )
			return haxe.io.Bytes.alloc(0);
		var k = haxe.crypto.Base64.decode(s);
		// old format support
		if( k.get(0) != 0x04 || k.get(1) != 0x22 || k.get(2) != 0x4D || k.get(3) != 0x18 )
			return k;
		#if lz4js
		var tmp = new js.lib.Uint8Array(k.length);
		for( i in 0...k.length ) tmp[i] = k.get(i);
		var k = Lz4js.decompress(tmp);
		var b = haxe.io.Bytes.alloc(k.length);
		for( i in 0...k.length ) b.set(i, k[i]);
		return b;
		#else
		return new Lz4Reader().read(k);
		#end
	}

	public static function encodeBytes( b : haxe.io.Bytes, compress : Bool ) : String {
		if( compress && b.length > 0 ) {
			#if lz4js
				var tmp = new js.lib.Uint8Array(b.length);
				for( i in 0...b.length ) tmp[i] = b.get(i);
				tmp = Lz4Reader.Lz4js.compress(tmp,65536);
				b = haxe.io.Bytes.alloc(tmp.length);
				for( i in 0...tmp.length )
					b.set(i, tmp[i]);
			#else
			// old format (no LZ4 compression support)
			#end
		}
		return haxe.crypto.Base64.encode(b);
	}

}