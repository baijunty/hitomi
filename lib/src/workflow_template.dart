final resizeWorkflow = {
  "client_id": "afd9fa7cd23b479ab9f7314393aab966",
  "prompt": {
    "10": {
      "inputs": {"image_path_or_url": ""},
      "class_type": "CustomImageLoader",
      "_meta": {"title": "Image Loader (Path or URL)"},
    },
    "42": {
      "inputs": {
        "text_0": "",
        "text": ["47", 0],
      },
      "class_type": "ShowText|pysssss",
      "_meta": {"title": "展示文本"},
    },
    "47": {
      "inputs": {
        "names": ["10", 2],
        "images": ["50", 0],
      },
      "class_type": "Image2Base64",
      "_meta": {"title": "Image to Base64"},
    },
    "50": {
      "inputs": {
        "shorter_edge": 384,
        "images": ["10", 0],
      },
      "class_type": "ResizeImagesByShorterEdge",
      "_meta": {"title": "Resize Images by Shorter Edge"},
    },
  },
  "partial_execution_targets": ["42"],
  "extra_data": {
    "extra_pnginfo": {
      "workflow": {
        "id": "3dd7e06e-efb3-44f6-827b-ccc8f46ec97d",
        "revision": 0,
        "last_node_id": 50,
        "last_link_id": 69,
        "nodes": [],
        "links": [],
        "groups": [],
        "config": {},
        "extra": {
          "ds": {
            "scale": 1,
            "offset": [314, 55],
          },
          "workflowRendererVersion": "Vue",
          "frontendVersion": "1.34.9",
          "VHS_latentpreview": false,
          "VHS_latentpreviewrate": 0,
          "VHS_MetadataImage": true,
          "VHS_KeepIntermediate": true,
        },
        "version": 0.4,
      },
    },
  },
};
final embeddingWorkflow = {
  "client_id": "afd9fa7cd23b479ab9f7314393aab966",
  "prompt": {
    "10": {
      "inputs": {"image_path_or_url": ""},
      "class_type": "CustomImageLoader",
      "_meta": {"title": "Image Loader (Path or URL)"},
    },
    "42": {
      "inputs": {
        "text_0": "",
        "text": ["54", 0],
      },
      "class_type": "ShowText|pysssss",
      "_meta": {"title": "展示文本"},
    },
    "51": {
      "inputs": {
        "crop": "center",
        "clip_vision": ["52", 0],
        "image": ["10", 0],
      },
      "class_type": "CLIPVisionEncode",
      "_meta": {"title": "CLIP视觉编码"},
    },
    "52": {
      "inputs": {"clip_name": "clip_vision_h.safetensors"},
      "class_type": "CLIPVisionLoader",
      "_meta": {"title": "CLIP视觉加载器"},
    },
    "54": {
      "inputs": {
        "name": ["10", 2],
        "vision_output": ["51", 0],
      },
      "class_type": "OutputEmbedding",
      "_meta": {"title": "Output Embedding to JSON"},
    },
  },
  "partial_execution_targets": ["42"],
  "extra_data": {
    "extra_pnginfo": {
      "workflow": {
        "id": "3dd7e06e-efb3-44f6-827b-ccc8f46ec97d",
        "revision": 0,
        "last_node_id": 54,
        "last_link_id": 77,
        "nodes": [],
        "links": [],
        "groups": [],
        "config": {},
        "extra": {
          "ds": {
            "scale": 1,
            "offset": [312, 55],
          },
          "workflowRendererVersion": "Vue",
          "frontendVersion": "1.34.9",
          "VHS_latentpreview": false,
          "VHS_latentpreviewrate": 0,
          "VHS_MetadataImage": true,
          "VHS_KeepIntermediate": true,
        },
        "version": 0.4,
      },
    },
  },
};
final imageHashWorkflow = {
  "client_id": "afd9fa7cd23b479ab9f7314393aab966",
  "prompt": {
    "10": {
      "inputs": {"image_path_or_url": ""},
      "class_type": "CustomImageLoader",
      "_meta": {"title": "Image Loader (Path or URL)"},
    },
    "42": {
      "inputs": {
        "text_0": "",
        "text": ["55", 0],
      },
      "class_type": "ShowText|pysssss",
      "_meta": {"title": "展示文本"},
    },
    "55": {
      "inputs": {
        "names": ["10", 2],
        "images": ["10", 0],
      },
      "class_type": "ImageHash",
      "_meta": {"title": "Image Hash"},
    },
  },
  "partial_execution_targets": ["42"],
  "extra_data": {
    "extra_pnginfo": {
      "workflow": {
        "id": "3dd7e06e-efb3-44f6-827b-ccc8f46ec97d",
        "revision": 0,
        "last_node_id": 55,
        "last_link_id": 81,
        "nodes": [],
        "links": [],
        "groups": [],
        "config": {},
        "extra": {
          "ds": {
            "scale": 1,
            "offset": [312, 55],
          },
          "workflowRendererVersion": "Vue",
          "frontendVersion": "1.34.9",
          "VHS_latentpreview": false,
          "VHS_latentpreviewrate": 0,
          "VHS_MetadataImage": true,
          "VHS_KeepIntermediate": true,
        },
        "version": 0.4,
      },
    },
  },
};
final tagTriggerWorkflow = {
  "client_id": "0a7e68c4d290420486a7f52482ec82e3",
  "prompt": {
    "10": {
      "inputs": {
        "model": "wd-vit-tagger-v3",
        "threshold": 0.35,
        "character_threshold": 0.85,
        "replace_underscore": true,
        "trailing_comma": true,
        "exclude_tags": "",
        "image": ["11", 0],
      },
      "class_type": "WD14Tagger|pysssss",
      "_meta": {"title": "WD14反推提示词"},
    },
    "11": {
      "inputs": {"image_path_or_url": ""},
      "class_type": "CustomImageLoader",
      "_meta": {"title": "Image Loader (Path or URL)"},
    },
    "12": {
      "inputs": {
        "text": ["10", 0],
      },
      "class_type": "ShowText|pysssss",
      "_meta": {"title": "展示文本"},
    },
  },
  "partial_execution_targets": ["12"],
  "extra_data": {
    "extra_pnginfo": {
      "workflow": {
        "id": "c49c7ca4-a28b-472d-a560-6f2413a0d39c",
        "revision": 0,
        "last_node_id": 12,
        "last_link_id": 12,
        "nodes": [],
        "links": [],
        "groups": [],
        "config": {},
        "extra": {
          "ds": {
            "scale": 1,
            "offset": [415, 51],
          },
          "workflowRendererVersion": "Vue",
          "frontendVersion": "1.34.9",
          "VHS_latentpreview": false,
          "VHS_latentpreviewrate": 0,
          "VHS_MetadataImage": true,
          "VHS_KeepIntermediate": true,
        },
        "version": 0.4,
      },
    },
  },
};
