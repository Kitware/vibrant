# Add the Vivia project to the vibrant build

add_project(vivia
            https://github.com/kitware/vivia.git
            "master"
            -DLIBJSON_INCLUDE_DIR:PATH=${LIBJSON_INCLUDE_DIR}
            -DLIBJSON_LIBRARY:PATH=${LIBJSON_LIBRARY}
            -DQT_QMAKE_EXECUTABLE:PATH=${fletch_DIR}/install/bin/qmake
            -DPROJ4_INCLUDE_DIR:PATH=${fletch_DIR}/install/include/
            -DPROJ4_LIBRARY:PATH=${fletch_DIR}/install/lib/${lib_pre}proj.${lib_ext}
            -DBOOST_ROOT:PATH=${fletch_DIR}/install/
            -DBOOST_INCLUDEDIR:PATH=${fletch_DIR}/install/include/
            -DBOOST_LIBRARYDIR:PATH=${fletch_DIR}/install/lib/
            -DVTK_DIR:PATH=${fletch_DIR}/install/lib/cmake/vtk-6.2
            -Dgeographiclib_DIR:PATH=${fletch_DIR}/build/src/GeographicLib-build
            -DKML_DIR:PATH=${fletch_DIR}/install/lib/cmake/
            -DVXL_DIR:PATH=${VXL_DIR}
            -Dvidtk_DIR:PATH=${vidtk_all_BINARY_DIR}
            -DUSE_VTK_62:BOOL=ON
            -DVISGUI_ENABLE_GDAL:BOOL=OFF
            )
