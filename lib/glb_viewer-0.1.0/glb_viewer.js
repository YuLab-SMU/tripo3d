HTMLWidgets.widget({

  name: 'glb_viewer',

  type: 'output',

  factory: function(el, width, height) {

    var camera, renderer, controls, scene;
    var animationId = null;

    function ensureImportmap() {
      if (document.querySelector('script[type="importmap"][data-tripo3d]')) {
        return;
      }
      var script = document.createElement('script');
      script.type = 'importmap';
      script.setAttribute('data-tripo3d', 'true');
      script.textContent = JSON.stringify({
        imports: {
          'three': 'https://unpkg.com/three@0.170.0/build/three.module.js',
          'three/addons/': 'https://unpkg.com/three@0.170.0/examples/jsm/'
        }
      });
      document.head.appendChild(script);
    }

    function decodeBase64(b64) {
      var binary = atob(b64);
      var bytes = new Uint8Array(binary.length);
      for (var i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
      }
      return bytes.buffer;
    }

    function setupScene(THREE, GLTFLoader, OrbitControls, x) {
      scene = new THREE.Scene();
      scene.background = new THREE.Color(x.background || '#f0f0f0');

      camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
      camera.position.set(3, 2, 3);
      camera.lookAt(0, 0, 0);

      renderer = new THREE.WebGLRenderer({ antialias: true });
      renderer.setSize(width, height);
      renderer.setPixelRatio(window.devicePixelRatio);
      renderer.shadowMap.enabled = true;
      el.appendChild(renderer.domElement);

      scene.add(new THREE.AmbientLight(0xffffff, 0.5));

      var keyLight = new THREE.DirectionalLight(0xffffff, 1.0);
      keyLight.position.set(5, 10, 7);
      scene.add(keyLight);

      var fillLight = new THREE.DirectionalLight(0xffffff, 0.4);
      fillLight.position.set(-3, 2, -2);
      scene.add(fillLight);

      var loader = new GLTFLoader();
      var buffer = decodeBase64(x.glb_base64);
      loader.parse(buffer, '', function(gltf) {
        var box = new THREE.Box3().setFromObject(gltf.scene);
        var center = box.getCenter(new THREE.Vector3());
        var size = box.getSize(new THREE.Vector3());
        var maxDim = Math.max(size.x, size.y, size.z);
        var scale = maxDim > 0 ? 2.5 / maxDim : 1;

        gltf.scene.position.sub(center);
        gltf.scene.scale.setScalar(scale);
        scene.add(gltf.scene);

        camera.position.set(center.x + 3, center.y + 2, center.z + 3);
        camera.lookAt(center);
      }, function(err) {
        el.innerHTML = '<div style="padding:20px;color:#c00;">' +
          'Failed to load GLB model: ' + (err.message || err) + '</div>';
      });

      controls = new OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.dampingFactor = 0.08;
      controls.target.set(0, 0, 0);
      controls.update();

      if (x.show_grid) {
        scene.add(new THREE.GridHelper(3, 24, 0xcccccc, 0xe0e0e0));
      }
    }

    function animate() {
      animationId = requestAnimationFrame(animate);
      if (controls) controls.update();
      if (renderer && scene && camera) {
        renderer.render(scene, camera);
      }
    }

    function cleanup() {
      if (animationId !== null) {
        cancelAnimationFrame(animationId);
        animationId = null;
      }
      if (renderer) {
        renderer.dispose();
        renderer.domElement.remove();
        renderer = null;
      }
      if (controls) {
        controls.dispose();
        controls = null;
      }
      camera = null;
      scene = null;
    }

    return {

      renderValue: function(x) {
        cleanup();
        el.innerHTML = '';

        ensureImportmap();

        Promise.all([
          import('three'),
          import('three/addons/loaders/GLTFLoader.js'),
          import('three/addons/controls/OrbitControls.js')
        ]).then(function(mods) {
          var THREE = mods[0];
          var GLTFLoader = mods[1].GLTFLoader;
          var OrbitControls = mods[2].OrbitControls;

          setupScene(THREE, GLTFLoader, OrbitControls, x);
          animate();
        }).catch(function(err) {
          el.innerHTML = '<div style="padding:20px;color:#c00;">' +
            'Failed to load Three.js: ' + (err.message || err) + '</div>';
        });
      },

      resize: function(width, height) {
        if (camera) {
          camera.aspect = width / height;
          camera.updateProjectionMatrix();
        }
        if (renderer) {
          renderer.setSize(width, height);
        }
      }

    };
  }
});
