set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)



add_executable(tests "")

target_sources(tests PRIVATE
        test_wire.cpp
        test_awdl_sync.cpp
        test_awdl_peers.cpp
        test_awdl_election.cpp
        test_awdl_channel.cpp
        test_awdl_txgate.cpp
)

target_include_directories(tests PRIVATE ${CMAKE_SOURCE_DIR}/src)

target_link_libraries(tests GTest::gtest GTest::gtest_main)
target_link_libraries(tests awdl)

add_test(NAME awdl_protocol COMMAND tests)
