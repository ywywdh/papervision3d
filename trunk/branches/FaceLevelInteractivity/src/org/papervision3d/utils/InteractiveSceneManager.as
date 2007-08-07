﻿/**
* ...
* @author John Grden
* @version 0.1
*/

package org.papervision3d.utils 
{
	import com.blitzagency.xray.logger.XrayLog;
	import flash.geom.Point;
	import org.papervision3d.components.as3.utils.CoordinateTools;
	
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;
	import flash.utils.Dictionary;
	
	import org.papervision3d.core.geom.Mesh3D;
	import org.papervision3d.core.geom.Face3DInstance;
	import org.papervision3d.core.geom.Face3D;
	import org.papervision3d.core.proto.CameraObject3D;
	import org.papervision3d.core.proto.SceneObject3D;
	import org.papervision3d.events.InteractiveScene3DEvent;
	import org.papervision3d.objects.DisplayObject3D;
	import org.papervision3d.utils.InteractiveSprite;
	import flash.events.Event;

	public class InteractiveSceneManager extends EventDispatcher
	{
		public static var DEFAULT_SPRITE_ALPHA						:Number = .0051;
		public static var DEFAULT_FILL_ALPHA						:Number = .0051;
		public static var DEFAULT_FILL_COLOR						:Number = 0xFFFFFF;
		public static var MOUSE_IS_DOWN								:Boolean = false;
		
		public var buttonMode										:Boolean = false;
		/**
		* This allows objects faces to have their own containers.  When set to true
		* and the DisplayObject3D.faceLevelMode = false, the faces will be drawn in ISM's layer of containers
		*/
		public var faceLevelMode  									:Boolean = false;
		
		/**
		* If the user sets this to true, then we monitor the allowDraw flag via mouse interaction.
		* If set to true, then leave DEFAULT_SPRITE_ALPHA and DEFAULT_FILL_ALPHA at their default values to avoid odd drawings over the 3D scene
		*/
		private var _mouseInteractionMode							:Boolean = false;
		public function set mouseInteractionMode(value:Boolean):void
		{
			_mouseInteractionMode = value;
			allowDraw = !value;
			if( value ) container.stage.addEventListener(MouseEvent.MOUSE_MOVE, handleStageMouseMove);
			if( !value ) container.stage.removeEventListener(MouseEvent.MOUSE_MOVE, handleStageMouseMove);
		}
		public function get mouseInteractionMode():Boolean { return _mouseInteractionMode; }
		public var faceDictionary									:Dictionary = new Dictionary();
		public var containerDictionary								:Dictionary = new Dictionary();
		public var container										:Sprite = new InteractiveSprite();
		public var scene											:SceneObject3D;
		
		public var debug											:Boolean = false;
		
		/**
		* Boolean flag used internally to turn off ISM drawing when it's not needed in the render loop.  This only applies if mouseInteractionMode is set to true.
		*/
		protected var allowDraw										:Boolean = true;
		
		protected var clickCoordinates								:Object = null;
		
		protected var log											:XrayLog = new XrayLog();
		
		public function InteractiveSceneManager(p_scene:SceneObject3D):void
		{
			scene = p_scene;
			scene.container.parent.addChild(container);
			container.x = scene.container.x;
			container.y = scene.container.y;
			container.stage.addEventListener(Event.RESIZE, handleResize);
			container.stage.addEventListener(MouseEvent.MOUSE_UP, handleReleaseOutside);
		}
		
		public function addInteractiveObject(container3d:Object):void
		{
			if(faceDictionary[container3d] == null) 
			{
				var icd:InteractiveContainerData = faceDictionary[container3d] = new InteractiveContainerData(container3d);
				
				// for reverse lookup when you have the sprite container
				containerDictionary[icd.container] = container3d;
				
				// add mouse events to be captured and passed along
				icd.container.addEventListener(MouseEvent.MOUSE_DOWN, handleMousePress);
				icd.container.addEventListener(MouseEvent.MOUSE_UP, handleMouseRelease);
				icd.container.addEventListener(MouseEvent.CLICK, handleMouseClick);
				icd.container.addEventListener(MouseEvent.MOUSE_OVER, handleMouseOver);
				icd.container.addEventListener(MouseEvent.MOUSE_OUT, handleMouseOut);
				icd.container.addEventListener(MouseEvent.MOUSE_MOVE, handleMouseMove);
				
				icd.container.buttonMode = buttonMode;
				
				if(debug) log.debug("addDisplayObject id", container3d.id, container3d.name, DEFAULT_SPRITE_ALPHA);
			}
		}
		
		public function drawFace(container3d:DisplayObject3D, face3d:Face3D, x0:Number, x1:Number, x2:Number, y0:Number, y1:Number, y2:Number ):void
		{
			// if we're face level on this DO3D, then we switch to the face3D object
			var container:Object = container3d;
			if(faceLevelMode || container3d.faceLevelMode) container = face3d;
			
			// add to the dictionary if not added already
			if(faceDictionary[container] == null) addInteractiveObject(container);
			
			// if ISM.faceLevelMode = false, and DO3D.faceLevelMode = true, then ISM isn't dealing with drawing the tri's just return and don't draw.
			// otherwise, we're in object level mode, and we draw
			//log.debug("drawFace", faceLevelMode, allowDraw);
			if( faceLevelMode && allowDraw )
			{
				var drawingContainer:InteractiveContainerData = faceDictionary[container];
				
				drawingContainer.container.graphics.beginFill(drawingContainer.color, drawingContainer.fillAlpha);
				drawingContainer.container.graphics.moveTo( x0, y0 );
				drawingContainer.container.graphics.lineTo( x1, y1 );
				drawingContainer.container.graphics.lineTo( x2, y2 );
				drawingContainer.container.graphics.endFill();
				drawingContainer.isDrawn = true;
			}
		}
		
		public function getSprite(container3d:DisplayObject3D):InteractiveSprite
		{
			return InteractiveContainerData(faceDictionary[container3d]).container;
		}
		
		public function getDisplayObject3D(sprite:InteractiveSprite):DisplayObject3D
		{
			return DisplayObject3D(containerDictionary[sprite]);
		}
		
		public function resizeStage():void
		{
			container.x = scene.container.x;
			container.y = scene.container.y;
		}
		
		public function resetFaces():void
		{			
			// clear all triangles/faces that have been drawn
			for each( var item:InteractiveContainerData in faceDictionary)
			{
				item.container.graphics.clear();
				item.sort = item.isDrawn;
				item.isDrawn = false;
			}
			
			// make sure the sprite is aligned with the scene's canvas
			resizeStage();
		}
		
		public function sortObjects():void
		{
			// called from the scene after the render loop is completed
			var sort:Array = [];
			
			for each( var item:InteractiveContainerData in faceDictionary)
			{
				if(!item.sort) continue;
				var distance:Number = item.screenZ;
				sort.push({container:item.container, distance:distance});
			}
			
			sort.sortOn("distance", Array.DESCENDING | Array.NUMERIC);
			
			for(var i:Number=0;i<sort.length;i++) container.addChild(sort[i].container);
			
			// after the render loop is complete, and we've sorted, we reset the allowDraw flag
			if( mouseInteractionMode ) allowDraw = false;
		}
		
		protected function handleMousePress(e:MouseEvent):void
		{
			MOUSE_IS_DOWN = true;
			dispatchObjectEvent(InteractiveScene3DEvent.OBJECT_PRESS, Sprite(e.currentTarget));
		}
		
		protected function handleMouseRelease(e:MouseEvent):void
		{
			MOUSE_IS_DOWN = false;
			dispatchObjectEvent(InteractiveScene3DEvent.OBJECT_RELEASE, Sprite(e.currentTarget));
		}
		
		protected function handleMouseClick(e:MouseEvent):void
		{
			dispatchObjectEvent(InteractiveScene3DEvent.OBJECT_CLICK, Sprite(e.currentTarget));
		}
		
		protected function handleMouseOver(e:MouseEvent):void
		{
			var eventType:String
			eventType = clickCoordinates == null || !mouseInteractionMode ? InteractiveScene3DEvent.OBJECT_OVER : InteractiveScene3DEvent.OBJECT_CLICK;
			clickCoordinates = null;
			dispatchObjectEvent(eventType, Sprite(e.currentTarget));
		}
		
		protected function handleMouseOut(e:MouseEvent):void
		{
			dispatchObjectEvent(InteractiveScene3DEvent.OBJECT_OUT, Sprite(e.currentTarget));
		}
		
		protected function handleMouseMove(e:MouseEvent):void
		{	
			dispatchObjectEvent(InteractiveScene3DEvent.OBJECT_MOVE, Sprite(e.currentTarget));
		}
		
		protected function handleReleaseOutside(e:MouseEvent):void
		{	
			if(debug) log.debug("releaseOutside");
			dispatchEvent(new InteractiveScene3DEvent(InteractiveScene3DEvent.OBJECT_RELEASE_OUTSIDE));
			MOUSE_IS_DOWN = false;
			clickCoordinates = {mouseX:this.container.mouseX, mouseY:this.container.mouseY};
			allowDraw = true;
		}
		
		protected function handleStageMouseMove(e:MouseEvent):void
		{
			allowDraw = true;
		}
		
		protected function dispatchObjectEvent(event:String, currentTarget:Sprite):void
		{
			if(debug) log.debug(event, DisplayObject3D(containerDictionary[currentTarget]).name);
			
			if(containerDictionary[currentTarget] is DisplayObject3D)
			{
				containerDictionary[currentTarget].dispatchEvent(new InteractiveScene3DEvent(event, containerDictionary[currentTarget], InteractiveSprite(currentTarget)));
				dispatchEvent(new InteractiveScene3DEvent(event, containerDictionary[currentTarget], InteractiveSprite(currentTarget), null, null));
			}else if(containerDictionary[currentTarget] is Face3D)
			{
				var face3d:Face3D = containerDictionary[currentTarget];
				var face3dContainer:InteractiveContainerData = faceDictionary[face3d];
				dispatchEvent(new InteractiveScene3DEvent(event, null, InteractiveSprite(currentTarget), face3d, face3dContainer));
			}
		}
		
		protected function handleResize(e:Event):void
		{
			resizeStage();
		}
	}
}
