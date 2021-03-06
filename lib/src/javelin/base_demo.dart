part of javelin;

/*

  Copyright (C) 2012 John McCutchan <john@johnmccutchan.com>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

*/


class JavelinDemoStatus {
  static final int DemoStatusOKAY = 0;
  static final int DemoStatusError = 1;
  JavelinDemoStatus(this.code, this.text);
  int code;
  String text;
}


class JavelinBaseDemo {
  JavelinKeyboard keyboard;
  JavelinMouse mouse;
  num _time;
  num _oldTime;
  num _accumTime;
  num _lastYaw;
  num _lastPitch;
  Viewport _viewPort;
  BlendState _blendState;
  BlendState _blendState1;
  DepthState _depthState;
  DepthState _depthState1;
  DepthState _depthState2;
  RasterizerState _rasterizerState;
  RasterizerState _rasterizerState1;
  RasterizerState _rasterizerState2;
  Element _element;
  GraphicsDevice _device;
  GraphicsContext _immediateContext;
  ResourceManager _resourceManager;
  DebugDrawManager _debugDrawManager;

  mat4 projectionMatrix;
  mat4 viewMatrix;
  mat4 projectionViewMatrix;
  mat4 normalMatrix;

  Float32Array projectionTransform;
  Float32Array viewTransform;
  Float32Array projectionViewTransform;
  Float32Array normalTransform;

  GraphicsDevice get device => _device;
  GraphicsContext get immediateContext => _immediateContext;
  DebugDrawManager get debugDrawManager => _debugDrawManager;
  ResourceManager get resourceManager => _resourceManager;
  RenderConfig get renderConfig => _renderConfig;

  RenderConfig _renderConfig;

  int frameCounter;

  bool _quit;
  Camera _camera;
  MouseKeyboardCameraController _cameraController;

  Camera get camera => _camera;

  int viewportWidth = 640;
  int viewportHeight = 480;

  JavelinBaseDemo(Element element, GraphicsDevice device,
                  ResourceManager resourceManager,
                  DebugDrawManager debugDrawManager) {
    _element = element;
    _device = device;
    _immediateContext = device.context;
    _resourceManager = resourceManager;
    _debugDrawManager = debugDrawManager;
    _renderConfig = new RenderConfig(_device);
    keyboard = new JavelinKeyboard();
    mouse = new JavelinMouse();
    _camera = new Camera();
    var d = JavelinConfigStorage.get('camera.position');
    _camera.position = d;
    _camera.focusPosition = JavelinConfigStorage.get('camera.focusPosition');
    _cameraController = new MouseKeyboardCameraController();
    _quit = false;
    _time = 0;
    _oldTime = 0;
    _accumTime = 0;
    _lastYaw = 0;
    _lastPitch = 0;
    projectionMatrix = new mat4.zero();
    viewMatrix = new mat4.zero();
    projectionViewMatrix = new mat4.zero();
    normalMatrix = new mat4.zero();
    projectionTransform = new Float32Array(16);
    viewTransform = new Float32Array(16);
    projectionViewTransform = new Float32Array(16);
    normalTransform = new Float32Array(16);
    frameCounter = 0;
  }

  void resize(num elementWidth, num elementHeight) {
    this.viewportWidth = elementWidth;
    this.viewportHeight = elementHeight;
    Viewport vp = _viewPort;
    if (vp == null) {
      return;
    }
    vp.x = 0;
    vp.y = 0;
    vp.width = elementWidth;
    vp.height = elementHeight;
    print('Resized to $elementWidth $elementHeight');
  }

  String get demoDescription => 'Base Demo';
  Element makeDemoUI() {
    return null;
  }
  Future<JavelinDemoStatus> startup() {
    Completer<JavelinDemoStatus> completer = new Completer();
    JavelinDemoStatus status = new JavelinDemoStatus(JavelinDemoStatus.DemoStatusOKAY, 'Base OKAY');
    completer.complete(status);
    {
      _viewPort = _device.createViewport('Default VP');
      _viewPort.x = 0;
      _viewPort.y = 0;
      _viewPort.width = viewportWidth;
      _viewPort.height = viewportHeight;
      _blendState = _device.createBlendState('BlendState.AlphaBlend');
      _blendState.blendEnable = true;
      _blendState.blendSourceColorFunc = BlendState.BlendSourceShaderAlpha;
      _blendState.blendDestColorFunc = BlendState.BlendSourceShaderInverseAlpha;
      _blendState.blendSourceAlphaFunc = BlendState.BlendSourceShaderAlpha;
      _blendState.blendDestAlphaFunc = BlendState.BlendSourceShaderInverseAlpha;
      _blendState1 = _device.createBlendState('BlendState.Opaque');
      _depthState = _device.createDepthState('DepthState.TestWrite');
      _depthState.depthTestEnabled = true;
      _depthState.depthWriteEnabled = true;
      _depthState.depthComparisonOp = DepthState.DepthComparisonOpLess;
      _depthState1 = _device.createDepthState('DepthState.Test');
      _depthState1.depthTestEnabled = true;
      _depthState1.depthComparisonOp = DepthState.DepthComparisonOpLess;
      _depthState2 = _device.createDepthState('DepthState.Write');
      _depthState2.depthWriteEnabled = true;
      _rasterizerState = _device.createRasterizerState(
          'RasterizerState.CCW.CullBack');
      _rasterizerState.cullEnabled = true;
      _rasterizerState.cullMode = RasterizerState.CullBack;
      _rasterizerState.cullFrontFace = RasterizerState.FrontCCW;
      _rasterizerState1 = _device.createRasterizerState(
          'RasterizerState.CCW.CullFront');
      _rasterizerState1.cullEnabled = true;
      _rasterizerState1.cullMode = RasterizerState.CullFront;
      _rasterizerState1.cullFrontFace = RasterizerState.FrontCCW;
      _rasterizerState2 = _device.createRasterizerState(
          'RasterizerState.CullDisabled');
      _rasterizerState2.cullEnabled = false;
    }
    document.on.keyDown.add(_keyDownHandler);
    document.on.keyUp.add(_keyUpHandler);
    _element.on.mouseMove.add(_mouseMoveHandler);
    _element.on.mouseDown.add(_mouseDownHandler);
    _element.on.mouseUp.add(_mouseUpHandler);
    _immediateContext.reset();
    return completer.future;
  }

  Future<JavelinDemoStatus> shutdown() {
    document.on.keyDown.remove(_keyDownHandler);
    document.on.keyUp.remove(_keyUpHandler);
    _element.on.mouseMove.remove(_mouseMoveHandler);
    _element.on.mouseDown.remove(_mouseDownHandler);
    _element.on.mouseUp.remove(_mouseUpHandler);
    _device.batchDeleteDeviceChildren([_rasterizerState, _rasterizerState1, _rasterizerState2, _depthState, _depthState1, _depthState2, _blendState, _blendState1, _viewPort]);
    _quit = true;
    Completer<JavelinDemoStatus> completer = new Completer();
    JavelinDemoStatus status = new JavelinDemoStatus(JavelinDemoStatus.DemoStatusOKAY, 'Base OKAY');
    status.code = JavelinDemoStatus.DemoStatusOKAY;
    status.text = '';
    completer.complete(status);
    return completer.future;
  }

  void run() {
    window.requestAnimationFrame(_animationFrame);
  }

  bool get shouldQuit => _quit;

  void _animationFrame(num highResTime) {
    if (shouldQuit) {
      return;
    }

    if (_time == 0 && _oldTime == 0) {
      // First time through
      _time = highResTime;
      _oldTime = highResTime;
      window.requestAnimationFrame(_animationFrame);
      return;
    }

    _oldTime = _time;
    _time = highResTime;
    num dt = _time - _oldTime;
    _accumTime += dt;

    update(_accumTime/1000.0, dt/1000.0);
    keyboard.frame();
    window.requestAnimationFrame(_animationFrame);
  }

  void drawGridRaw(int gridLines, vec3 x, vec3 z, vec4 color) {
    final double midLine = gridLines~/2.toDouble();
    vec3 o = new vec3.zero();
    o.sub(z.scaled(midLine));
    o.sub(x.scaled(midLine));

    for (int i = 0; i <= gridLines; i++) {
      vec3 start = o + (z.scaled(i-midLine)) + (x.scaled(-midLine));
      vec3 end = o + (z.scaled(i-midLine)) + (x.scaled(midLine));
      debugDrawManager.addLine(start, end, color);
    }

    for (int i = 0; i <= gridLines; i++) {
      vec3 start = o + (x.scaled(i-midLine)) + (z.scaled(-midLine));
      vec3 end = o + (x.scaled(i-midLine)) + (z.scaled(midLine));
      debugDrawManager.addLine(start, end, color);
    }
  }

  void drawGrid(int gridLines) {
    drawGridRaw(gridLines, new vec3(1.0, 0.0, 0.0),
                new vec3(0.0, 0.0, 1.0),
                new vec4(0.0, 1.0, 0.0, 1.0));
  }

  void drawHolodeck(int gridLines) {
    vec3 x = new vec3(1.0, 0.0, 0.0);
    vec3 y = new vec3(0.0, 1.0, 0.0);
    vec3 z = new vec3(0.0, 0.0, 1.0);
    vec4 colorRed = new vec4(1.0, 0.0, 0.0, 1.0);
    vec4 colorGreen = new vec4(0.0, 1.0, 0.0, 1.0);
    vec4 colorBlue = new vec4(0.0, 0.0, 1.0, 1.0);
    drawGridRaw(gridLines, x, z, colorGreen);
    drawGridRaw(gridLines, -y, z, colorBlue);
    drawGridRaw(gridLines, -y, x, colorRed);
  }

  void update(num time, num dt) {

    _cameraController.forward = keyboard.isDown(JavelinKeyCodes.KeyW);
    _cameraController.backward = keyboard.isDown(JavelinKeyCodes.KeyS);
    _cameraController.strafeLeft = keyboard.isDown(JavelinKeyCodes.KeyA);
    _cameraController.strafeRight = keyboard.isDown(JavelinKeyCodes.KeyD);
    _cameraController.UpdateCamera(dt, _camera);
    {
      _camera.copyViewMatrix(viewMatrix);
      _camera.copyProjectionMatrix(projectionMatrix);
      _camera.copyProjectionMatrix(projectionViewMatrix);
      projectionViewMatrix.multiply(viewMatrix);
      _camera.copyNormalMatrix(normalMatrix);
      normalMatrix.setTranslation(new vec3(0.0, 0.0, 0.0));
      projectionMatrix.copyIntoArray(projectionTransform);
      viewMatrix.copyIntoArray(viewTransform);
      projectionViewMatrix.copyIntoArray(projectionViewTransform);
      normalMatrix.copyIntoArray(normalTransform);
    }
    JavelinConfigStorage.set('camera.focusPosition', _camera.focusPosition);
    JavelinConfigStorage.set('camera.position', _camera.position);
    {
      num yaw = _camera.yaw;
      num pitch = _camera.pitch;
      num deltaYaw = yaw - _lastYaw;
      num deltaPitch = pitch - _lastPitch;
      _lastYaw = yaw;
      _lastPitch = pitch;
      if (abs(deltaYaw) > 0.00001) {
        //spectreLog.Info('Camera Yaw: $deltaYaw');
      }
      if (abs(deltaPitch) > 0.00001) {
        //spectreLog.Info('Camera Pitch: $deltaPitch');
      }
    }
    immediateContext.clearColorBuffer(0.0, 0.0, 0.0, 1.0);
    immediateContext.clearDepthBuffer(1.0);
    immediateContext.reset();
    immediateContext.setBlendState(_blendState);
    immediateContext.setRasterizerState(_rasterizerState);
    immediateContext.setDepthState(_depthState);
    immediateContext.setViewport(_viewPort);
    debugDrawManager.update(dt);

    frameCounter++;
  }

  void keyboardEventHandler(KeyboardEvent event, bool down) {
    keyboard.keyboardEvent(event, down);
  }

  void mouseMoveEventHandler(MouseEvent event) {
    mouse.mouseMoveEvent(event);
    if (mouse.locked) {
      _cameraController.accumDX += event.webkitMovementX;
      _cameraController.accumDY += event.webkitMovementY;
    }
  }

  void mouseButtonEventHandler(MouseEvent event, bool down) {
    mouse.mouseButtonEvent(event, down);
  }

  void _keyDownHandler(KeyboardEvent event) {
    keyboardEventHandler(event, true);
  }

  void _keyUpHandler(KeyboardEvent event) {
    keyboardEventHandler(event, false);
  }

  void _mouseDownHandler(MouseEvent event) {
    mouseButtonEventHandler(event, true);
  }

  void _mouseUpHandler(MouseEvent event) {
    mouseButtonEventHandler(event, false);
  }

  void _mouseMoveHandler(MouseEvent event) {
    mouseMoveEventHandler(event);
  }
}
