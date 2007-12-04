package org.papervision3d.core.render.shader
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.BlendMode;
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;
	
	import org.papervision3d.core.render.data.RenderSessionData;
	import org.papervision3d.materials.shaders.Shader;
	
	/**
	 * Author Ralph Hauwert
	 */
	public class ShaderRenderer extends EventDispatcher implements IShaderRenderer
	{
		public var bitmapLayer:Sprite;
		public var container:Sprite;
		public var bitmapContainer:Bitmap;
		public var shadeLayers:Dictionary;
		
		public var outputBitmap:BitmapData;
		private var _inputBitmapData:BitmapData;
		
		public function ShaderRenderer()
		{
			container = new Sprite();
	
			bitmapLayer = new Sprite();
			bitmapContainer = new Bitmap();
			
			bitmapLayer.addChild(bitmapContainer);
			bitmapLayer.blendMode = BlendMode.NORMAL;
			
			shadeLayers = new Dictionary();
			container.addChild(bitmapLayer);
		}
		
		public function render(renderSessionData:RenderSessionData):void
		{
			outputBitmap.fillRect(outputBitmap.rect, 0x000000);
			bitmapContainer.bitmapData = inputBitmap;
			outputBitmap.draw(container, null, null, null, outputBitmap.rect, false);
		}
		
		public function clear():void
		{
			var sprite:Sprite;
			for each(sprite in shadeLayers){
				sprite.graphics.clear();
				sprite.graphics.beginFill(0,1);
				sprite.graphics.drawRect(0,0,inputBitmap.width, inputBitmap.height);
				sprite.graphics.endFill();
			}
		}
		
		public function destroy():void
		{
			bitmapLayer = null;
			//TODO : Destroy all shaderlayers.
			outputBitmap.dispose();
		}
		
		public function getLayerForShader(shader:Shader):Sprite
		{
			var layer:Sprite = new Sprite();
			shadeLayers[shader] = layer;
			var rect:Sprite = new Sprite();
			layer.addChild(rect);
			rect.graphics.beginFill(0,0);
			rect.graphics.drawRect(0,0,inputBitmap.width, inputBitmap.height);
			rect.graphics.endFill();
			
			container.addChild(layer);
		
			layer.blendMode = shader.layerBlendMode;
			
			return layer;
		}
		
		public function set inputBitmap(bitmapData:BitmapData):void
		{
			_inputBitmapData = bitmapData;
			outputBitmap = _inputBitmapData.clone();
		}
		
		public function get inputBitmap():BitmapData
		{
			return _inputBitmapData;	
		}
		
	}
}