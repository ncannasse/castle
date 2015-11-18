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
package cdb.jq;

enum Message {
	Create( id : Int, name : String, ?attr : Array<{ name : String, value : String }> );
	AddClass( id : Int, name : String );
	RemoveClass( id : Int, name : String );
	Append( id : Int, to : Int );
	CreateText( id : Int, text : String, ?pid : Int );
	Reset( id : Int );
	Dock( pid : Int, id : Int, dir : DockDirection, size : Null<Float> );
	Remove( id : Int );
	Event( id : Int, name : String, eid : Int );
	SetAttr( id : Int, att : String, ?val : String );
	SetStyle( id : Int, st : String, ?val : String );
	Trigger( id : Int, name : String );
	Special( id : Int, name : String, args : Array<Dynamic>, ?eid : Int );
	Anim( id : Int, name : String, ?dur : Float );
	Dispose( id : Int, ?events : Array<Int> );
	Unbind( events : Array<Int> );
}

typedef EventProps = { ?keyCode : Int, ?value : Dynamic, ?which : Int, ?ctrlKey : Bool, ?shiftKey : Bool };

enum Answer {
	Event( eid : Int, ?props : EventProps );
	SetValue( id : Int, value : String );
	Done( eid : Int );
}

enum DockDirection {
	Left;
	Right;
	Up;
	Down;
	Fill;
}
