## 许可证

除文件头或子目录内另有许可证声明的部分外，本项目默认采用木兰宽松许可证，第2版，详见根目录 [LICENSE](LICENSE)。

## 构建步骤

### 1.使用Kernel内置板级构建
    ./tbox                                  #更新板级,让cmake知道有哪些板级可以选择
    ./tbox toolchain --list                 #查看可选择使用的工具链
    ./tbox toolchain <toolchain>            #选择板级对应工具链
    export PATH=/opt/<toolchain>/bin:$PATH  #设置工具链环境变量
    cmake --preset <board>                  #选择板级进行构建



构建器会根据当前pc环境自动选择 `make` 或者 `ninja`  完成后输出以下信息:

```
==================================================
CMake Generator: Ninja
To build the project, run:
  ninja -C /home/wql/devlep/ttos-n/build/aarch64/qemu
==================================================
```



编译（任选一种， 如果是 `make` ，将下面的 `ninja `换成 `make` 即可）:

- `ninja -C ./build/aarch64/qemu-aarch64/`

- `cmake --build --preset qemu-aarch64`

- `cd build/aarch64/qemu-aarch64/&&ninja`

---


### 2.使用板级拓展包构建

​	板级拓展包主要是由项目产生，每个项目可以独立管理自己的板级拓展包，以项目为单位，每个包中可以有多个板级


**板级拓展包的所有命令都是 tbox --ext 前缀**

- `tbox --ext --list 			#查看支持的板级拓展包`
- `tbox --ext --board	<pkg>	#选择对应的板级拓展包`
- `tbox --ext --index	<path>	#使用本地的板级拓展包索引文件`
- `tbox --ext --board <pkg> --force-board	#板级仓库 dirty 时强制覆盖到远端 ref`
- `tbox --ext --offline-export <pkg.tar.gz>	#将当前 boards-prj + dependencies 导出为离线包`
- `tbox --ext --offline-import <pkg.tar.gz>	#从离线包导入 boards-prj + dependencies（并启用离线依赖模式）`
- `tbox --ext --offline-import <pkg.tar.gz> --force-import	#存在 dirty 仓库时强制导入`


离线包导入后会在项目根目录生成 `.upboard-offline`，后续构建不会再从网络拉取 dependencies。  
如需恢复联网拉取，删除 `.upboard-offline`。

`tbox` 二级参数自动补全（bash）:

```
source <(./tbox completion bash)
```

如需长期生效，可加入 `~/.bashrc`。

### 3.tbox命令清单（补充）

- `tbox                             #按默认 schema 扫描板级并生成 CMakePresets.json，随后生成 Kconfig.auto`
- `tbox -f <board.yaml>             #只生成指定板级的 preset`
- `tbox -h | --help | ?             #显示帮助`
- `tbox vscode                      #复制 vscode 模板到 .vscode（已存在文件会跳过）`
- `tbox completion [bash]           #输出补全脚本，配合 source <(...) 使用`
- `tbox --ext -h | --help           #查看 ext 子命令帮助`
- `tbox --toolchain -h              #查看 toolchain 子命令帮助 `

