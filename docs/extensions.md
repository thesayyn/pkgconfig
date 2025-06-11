<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="pkgconfig_module_impl"></a>

## pkgconfig_module_impl

<pre>
pkgconfig_module_impl(<a href="#pkgconfig_module_impl-mctx">mctx</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pkgconfig_module_impl-mctx"></a>mctx |  <p align="center"> - </p>   |  none |


<a id="pc_import_lib"></a>

## pc_import_lib

<pre>
pc_import_lib(<a href="#pc_import_lib-name">name</a>, <a href="#pc_import_lib-deps">deps</a>, <a href="#pc_import_lib-includedir">includedir</a>, <a href="#pc_import_lib-includes">includes</a>, <a href="#pc_import_lib-libdir">libdir</a>, <a href="#pc_import_lib-libname">libname</a>, <a href="#pc_import_lib-linkopts">linkopts</a>, <a href="#pc_import_lib-repo_mapping">repo_mapping</a>)
</pre>

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="pc_import_lib-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="pc_import_lib-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="pc_import_lib-includedir"></a>includedir |  -   | String | optional |  `""`  |
| <a id="pc_import_lib-includes"></a>includes |  -   | List of strings | optional |  `[]`  |
| <a id="pc_import_lib-libdir"></a>libdir |  -   | String | optional |  `""`  |
| <a id="pc_import_lib-libname"></a>libname |  -   | String | optional |  `""`  |
| <a id="pc_import_lib-linkopts"></a>linkopts |  -   | List of strings | optional |  `[]`  |
| <a id="pc_import_lib-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |


<a id="pkgconfig"></a>

## pkgconfig

<pre>
pkgconfig = use_extension("@pkgconfig//:extensions.bzl", "pkgconfig")
pkgconfig.setup(<a href="#pkgconfig.setup-isolate">isolate</a>, <a href="#pkgconfig.setup-paths">paths</a>)
pkgconfig.lib(<a href="#pkgconfig.lib-name">name</a>)
</pre>


**TAG CLASSES**

<a id="pkgconfig.setup"></a>

### setup

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="pkgconfig.setup-isolate"></a>isolate |  -   | Boolean | optional |  `False`  |
| <a id="pkgconfig.setup-paths"></a>paths |  -   | List of strings | optional |  `[]`  |

<a id="pkgconfig.lib"></a>

### lib

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="pkgconfig.lib-name"></a>name |  -   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | optional |  `""`  |


