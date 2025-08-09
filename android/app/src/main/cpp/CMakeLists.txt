# Menentukan versi minimum CMake yang dibutuhkan.
# Gradle akan memeriksa ini.
cmake_minimum_required(VERSION 3.6)

# Perintah untuk membuat library C++ Anda.
# 'native-lib' adalah nama library yang akan kita gunakan di kode Kotlin.
# 'SHARED' berarti library ini akan menjadi file .so (Shared Object).
# 'native-lib.cpp' adalah file sumber C++ yang akan dikompilasi.
add_library(
        native-lib
        SHARED
        native-lib.cpp)

# Mencari library logging bawaan Android untuk digunakan jika perlu.
find_library(
        log-lib
        log)

# Menghubungkan library logging ke library native kita.
target_link_libraries(
        native-lib
        ${log-lib})