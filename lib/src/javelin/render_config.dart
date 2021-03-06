part of javelin;

class RenderResource {
  String name;
  String type;
  int width;
  int height;
  String format;
  DeviceChild handle;
  RenderResource(this.name, this.type, this.width, this.height, this.format, this.handle);
}

class RenderLayer {
  String name;
  String sort;
  String type;
  RenderTarget handle;
  RenderLayer(this.name, this.type, this.sort, this.handle);
}

class RenderConfig {
  Map _conf;
  Map<String, RenderLayer> _layers;
  Map<String, RenderResource> _buffers;
  GraphicsDevice _device;

  RenderConfig(this._device) {
    _buffers = new Map<String, RenderResource>();
    _layers = new Map<String, RenderLayer>();
  }

  void cleanup() {
    _layers.forEach((k,v) {
      spectreLog.Info('Destroying render layer $k');
      if (v.handle != null) {
        _device.deleteDeviceChild(v.handle);
      }
    });
    _layers.clear();
    _buffers.forEach((k,v) {
      spectreLog.Info('Destroying render resource $k');
      _device.deleteDeviceChild(v.handle);
    });
    _buffers.clear();
    _conf = null;
  }

  void setup() {
    List globalBuffers = _conf['global_buffers'];
    List layers = _conf['layers'];

    globalBuffers.forEach((bufferDesc) {
      String name = bufferDesc['name'];
      String type = bufferDesc['type'];
      int width = bufferDesc['width'];
      int height = bufferDesc['height'];
      String format = bufferDesc['format'];
      DeviceChild handle;
      if (type == 'depth') {
        RenderBuffer rb = _device.createRenderBuffer(name);
        rb.allocateStorage(width, height, RenderBuffer.stringToFormat(format));
        handle = rb;
      } else {
        Texture2D t2d = _device.createTexture2D(name);
        t2d.textureFormat = SpectreTexture.stringToFormat(format);
        t2d.uploadPixelArray(width, height, null);
        handle = t2d;
      }
      if (handle == null) {
        spectreLog.Error('Could not create render buffer $bufferDesc');
      } else {
        spectreLog.Info('Creating $type buffer $name');
        _buffers[name] = new RenderResource(name, type, width, height, format, handle);
      }
    });

    layers.forEach((layerDesc) {
      String name = layerDesc['name'];
      String type = layerDesc['type'];
      String color = layerDesc['color_target'];
      String depth = layerDesc['depth_target'];
      String sort = layerDesc['sort'];
      if (color == "system" && depth == "system") {
        // Layer only depends on system, 0 handle
        spectreLog.Info('Created system render layer $name');
        _layers[name] = new RenderLayer(name, type, sort, null);
      } else {
        if (color == "system" || depth == "system") {
          spectreLog.Error('Cannot create a layer that uses some system and some non-system buffers');
        } else {
          DeviceChild colorBuffer;
          DeviceChild depthBuffer;
          if (color != null) {
            RenderResource cb = _buffers[color];
            colorBuffer = cb.handle;
          }
          if (depth != null) {
            RenderResource db = _buffers[depth];
            depthBuffer = db.handle;
          }
          RenderTarget renderTargetHandle;
          renderTargetHandle = _device.createRenderTarget(name);
          renderTargetHandle.colorTarget = colorBuffer;
          renderTargetHandle.depthTarget = depthBuffer;
          spectreLog.Info('Created render layer $name');
          _layers[name] = new RenderLayer(name, type, sort, renderTargetHandle);
        }
      }
    });
  }

  DeviceChild getBuffer(String bufferName) {
    RenderResource resource = _buffers[bufferName];
    return resource.handle;
  }

  RenderTarget getLayer(String layerName) {
    RenderLayer layer = _layers[layerName];
    return layer.handle;
  }

  void load(Map<String, dynamic> conf) {
    cleanup();
    _conf = conf;
    setup();
  }

  void setupLayer(String layerName) {
    RenderLayer layer = _layers[layerName];
    _device.context.setRenderTarget(layer.handle);
  }
}
