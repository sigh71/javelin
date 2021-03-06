part of javelin_scene;

class Loader {
  Set<ResourceBase> _resourceHandleTable;
  Set<DeviceChild> _deviceHandleTable;
  Map _sceneDescription;
  Scene _scene;
  GraphicsDevice _device;
  ResourceManager _resourceManager;
  SceneResource sceneResourceHandle;
  Loader(this._scene, this._device, this._resourceManager) {
    _resourceHandleTable = new Set<ResourceBase>();
    _deviceHandleTable = new Set<DeviceChild>();
    sceneResourceHandle = null;
  }

  void shutdown() {
    _resourceHandleTable.forEach((r) {
      _resourceManager.deregisterResource(r);
    });
    _deviceHandleTable.forEach((d) {
      _device.deleteDeviceChild(d);
    });
    _deviceHandleTable.clear();
    _resourceHandleTable.clear();
    _resourceManager.removeEventCallback(sceneResourceHandle,  ResourceEvents.TypeUpdate, reload);
  }

  void reload(int type, SceneResource resource) {
    print('reloading');
    load(resource.sceneDescription);
  }

  Future loadFromUrl(String url) {
    sceneResourceHandle = _resourceManager.registerResource(url);
    _resourceManager.addEventCallback(sceneResourceHandle, ResourceEvents.TypeUpdate, reload);
    return _resourceManager.loadResource(sceneResourceHandle);
  }

  Future _loadResources(Map sceneDescription) {
    Set<String> resources = new Set<String>();
    sceneDescription['resources'].forEach((r) {
      resources.add(r);
    });
    var en = sceneDescription['entities'];
    en.forEach((Map e) {
      String shader = e['shader'];
      if (shader != null) {
        resources.add(shader);
      }
      String mesh = e['mesh'];
      Map<String, String> textures = e['textures'];
      if (mesh != null) {
        resources.add(mesh);
      }
      if (textures != null) {
        textures.forEach((k, v) {
          resources.add(v);
        });
      }
    });
    en = sceneDescription['materials'];
    en.forEach((Map e) {
      resources.add(e['shader']);
      Map<String, String> textures = e['textures'];
      if (textures != null) {
        textures.forEach((k, v) {
          resources.add(v);
        });
      }
    });
    resources.forEach((r) {
      ResourceBase handle = _resourceManager.getResource(r);
      if (handle != null) {
        // Duplicate
        return;
      }
      handle = _resourceManager.registerResource(r);
      ResourceBase rb = handle;
      if (rb is ImageResource) {
        Texture2D textureHandle = _device.createTexture2D(rb.url);
        _resourceManager.addEventCallback(handle, ResourceEvents.TypeUpdate, (type, resource) {
          textureHandle.uploadElement(handle.image);
          textureHandle.generateMipmap();
          spectreLog.Info('Updated texture - ${rb.url}');
        });
        _deviceHandleTable.add(textureHandle);
      }
      _resourceHandleTable.add(handle);
    });
    return _resourceManager.loadResources(_resourceHandleTable, false);
  }

  Mesh _loadMesh(Map entity) {
    final String name = entity['mesh'];
    print('_loadMesh $name');
    Mesh mesh = _scene.meshes[name];
    if (mesh == null) {
      mesh = new Mesh(name, _scene);
      _scene.meshes[name] = mesh;
    }
    mesh.load({});
    return mesh;
  }

  Material _loadMaterial(Map entity) {
    final String name = entity['name'];
    Material material = _scene.materials[name];
    if (material == null) {
      material = new Material(name, _scene);
      _scene.materials[name] = material;
    }
    material.load(entity);
    return material;
  }

  MaterialInstance _loadMaterialInstance(Map entity) {
    String materialName = entity['material'];
    if (materialName == null) {
      return null;
    }
    Material material = _scene.materials[materialName];
    if (material == null) {
      spectreLog.Error('No material named $materialName');
      return null;
    }
    String materialInstanceName = '${entity['material']}.${entity['name']}';
    MaterialInstance materialInstance = _scene.materialInstances[materialInstanceName];
    if (materialInstance == null) {
      materialInstance = new MaterialInstance(materialInstanceName, material, _scene);
      _scene.materialInstances[materialInstanceName] = materialInstance;
    }
    materialInstance.load(entity);
    return materialInstance;
  }

  void _spawnSkybox(Map entity) {
    if (_scene.skybox != null) {
      _scene.skybox.fini();
      _scene.skybox = null;
    }

    String shaderName = entity['shader'];

    ShaderProgramResource spr = _scene.resourceManager.getResource(shaderName);

    if (_scene.skyboxVertexShader == null) {
      _scene.skyboxVertexShader = _scene.device.createVertexShader('$shaderName.vs');
    }
    if (_scene.skyboxFragmentShader == null) {
      _scene.skyboxFragmentShader = _scene.device.createFragmentShader('$shaderName.fs');
    }
    if (_scene.skyboxShaderProgram == null) {
      _scene.skyboxShaderProgram = _scene.device.createShaderProgram('$shaderName.sp');
    }

    bool relink = false;
    VertexShader vs = _scene.skyboxVertexShader;
    if (vs.source != spr.vertexShaderSource) {
      vs.source = spr.vertexShaderSource;
      vs.compile();
      relink = true;
    }

    FragmentShader fs = _scene.skyboxFragmentShader;
    if (fs.source != spr.fragmentShaderSource) {
      fs.source = spr.fragmentShaderSource;
      fs.compile();
      relink = true;
    }

    ShaderProgram sp = _scene.skyboxShaderProgram;
    if (!sp.linked || relink) {
      _scene.device.configureDeviceChild(_scene.skyboxShaderProgram, {
        'VertexProgram': _scene.skyboxVertexShader,
        'FragmentProgram': _scene.skyboxFragmentShader,
      });
    }

    String texture0 = entity['textures']['0'];
    String texture1 = entity['textures']['1'];
    Texture2D texture0Handle = _scene.device.getDeviceChild(texture0);
    Texture2D texture1Handle = _scene.device.getDeviceChild(texture1);
    _scene.skybox = new Skybox(_device, _scene.resourceManager,
                                _scene.skyboxShaderProgram,
                                texture0Handle,
                                texture1Handle);
    _scene.skybox.init();
  }

  void _spawnModel(Map entity) {
    String materialInstanceName = '${entity['material']}.${entity['name']}';
    MaterialInstance materialInstance = _scene.materialInstances[materialInstanceName];
    Mesh mesh = _scene.meshes[entity['mesh']];
    Model model = _scene.models[entity['name']];
    if (model == null) {
      model = new Model(entity['name'], _scene);
      _scene.models[entity['name']] = model;
    }
    model.update(materialInstance, mesh, materialInstance.material.meshinputs);
  }

  void _setModelTransform(String name, Map transform) {
    Model model = _scene.models[name];
    if (model == null) {
      return;
    }
    TransformGraphNode node = model.transformHandle;
    if (transform['controller'] != null) {
      model.controller = new TransformController(_scene.transformGraph, node);
      model.controller.load(transform);
    }
    mat4 T = _scene.transformGraph.refLocalMatrix(node);
    T.setIdentity();
    num rotateX = transform['rotateX'];
    num rotateY = transform['rotateY'];
    num rotateZ = transform['rotateZ'];
    List<num> translate = transform['translate'];
    List<num> scale = transform['scale'];
    if (rotateX != null) {
      T.rotateX(rotateX);
    }
    if (rotateY != null) {
      T.rotateY(rotateY);
    }
    if (rotateZ != null) {
      T.rotateZ(rotateZ);
    }
    if (translate != null) {
      T.translate(translate[0], translate[1], translate[2]);
    }
    if (scale != null) {
      T.scale(scale[0], scale[1], scale[2]);
    }
    String parent = transform['parent'];
    if (parent != null) {
      _scene.transformGraph.unparent(node);
      Model parentModel = _scene.models[parent];
      if (parentModel != null) {
        _scene.transformGraph.reparent(node, parentModel.transformHandle);
      }
    }
  }

  void _spawnUniformset(Map entity) {
  }

  Future _loadEntities(bool resourcesLoaded) {
    Completer<bool> completer = new Completer<bool>();
    if (!resourcesLoaded) {
      completer.complete(false);
      return completer.future;
    }
    // Materials
    _sceneDescription['materials'].forEach((m) {
      _loadMaterial(m);
    });

    var foo = _sceneDescription['entities'];
    print('$foo');
    _sceneDescription['entities'].forEach((e) {
      _loadMaterialInstance(e);
    });

    Set<String> existingModels = new Set<String>();
    // Create entities
    _sceneDescription['entities'].forEach((e) {
      if (e['mesh'] != null) {
        _loadMesh(e);
      }
      if (e['type'] == 'skybox') {
        _spawnSkybox(e);
      }
      if (e['type'] == 'model') {
        existingModels.add(e['name']);
        _spawnModel(e);
      }
      if (e['type'] == 'uniformset') {
        _spawnUniformset(e);
      }
    });

    // Setup transforms
    _sceneDescription['entities'].forEach((e) {
      if (e['type'] != 'model') {
        return;
      }
      Map transform = e['transform'];
      if (transform == null) {
        return;
      }
      _setModelTransform(e['name'], transform);
    });

    _scene.reloaded(existingModels);

    completer.complete(true);
    return completer.future;
  }

  Future load(Map sceneDescription) {
    if (_sceneDescription != null) {
      _sceneDescription = sceneDescription;
      // TODO: Compute delta
      return _loadResources(sceneDescription).chain(_loadEntities);
    } else {
      _sceneDescription = sceneDescription;
      return _loadResources(sceneDescription).chain(_loadEntities);
    }
  }

  void setupScene() {
    print('setup scene!');
  }
}