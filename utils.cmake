cmake_minimum_required (VERSION 3.13)

include_guard(GLOBAL)

message(STATUS   "\n")
message(STATUS   ":===================:")
message(STATUS   ":loading utils.cmake:")
message(STATUS   ":===================:\n")

function(message)

  # message function override
  list(GET ARGV 0 MessageType)
  list(REMOVE_AT ARGV 0)
  if(MessageType STREQUAL DEBUG)
	if(VERBOSE)
		_message(STATUS "[debug] ${ARGV}")
	endif()
  else()
    _message(${MessageType} "${ARGV}")
  endif()
endfunction(message)

function(Find_WSL)

	# utility to find if wsl is the host env	
	if(UNIX)

		set(CMD_RES "")
		set(CMD_OUT "")
		set(CMD_ERR "")
		
		execute_process(
			COMMAND /usr/bin/uname -r 
			RESULT_VARIABLE CMD_RES
			OUTPUT_VARIABLE CMD_OUT
			ERROR_VARIABLE CMD_ERR
		)
		
		message(DEBUG "WSL lookup result: ${CMD_RES}")
		message(DEBUG "WSL lookup cout:   ${CMD_OUT}")
		message(DEBUG "WSL lookup cerr:   ${CMD_ERR}")

		if (${CMD_RES} EQUAL 1)
			message(FATAL_ERROR "WSL lookup returned the error: ${CMD_ERR}")
		endif()

		set(RGX_OUT "")
		string(REGEX MATCH "^.*Microsoft.*$" RGX_OUT ${CMD_OUT})
		message(DEBUG "WSL regex match result: ${RGX_OUT}")

		if(RGX_OUT STREQUAL "")
			set(WSL_Found OFF PARENT_SCOPE)
		else()
			set(WSL_Found ON PARENT_SCOPE)
		endif()
	else()
		set(WSL_Found OFF PARENT_SCOPE)	

	endif(UNIX)
endfunction(Find_WSL)

function(find_conan)

    set(options)
	set(oneValueArgs BINDIR REQUIRES)
	set(multiValueArgs)

	cmake_parse_arguments(
		FIND_CONAN "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if(NOT EXISTS "${CMAKE_BINARY_DIR}/conan.cmake")

	    message(STATUS "Downloading conan.cmake from https://github.com/conan-io/cmake-conan")

		# TODO: compatible version with windows AND wsl
		#execute_process(
		#	COMMAND /usr/bin/wget https://github.com/conan-io/cmake-conan/raw/v0.15/conan.cmake
		#	WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
		#)
   
	   # this one silently fails in WSL
	   file(DOWNLOAD "https://github.com/conan-io/cmake-conan/raw/v0.15/conan.cmake"
	       "${CMAKE_BINARY_DIR}/conan.cmake")
	endif()

	include("${CMAKE_BINARY_DIR}/conan.cmake")
	set(CMAKE_PROGRAM_PATH "${FIND_CONAN_BINDIR};${CMAKE_PROGRAM_PATH}")
	conan_check(VERSION ${FIND_CONAN_REQUIRES} REQUIRED)

endfunction(find_conan)

function(get_current_date)

	# usage 
	#set(CURRENT_DATE "")
	#get_current_date(
	#    OUT CURRENT_DATE
	#    FORMAT "+%Y-%m-%d"
	#)

	set(options)
	set(oneValueArgs OUT FORMAT)
	set(multiValueArgs)

	cmake_parse_arguments(
		GET_DATE "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	message(DEBUG "GET_DATE_OUT value is ${GET_DATE_OUT}")

	IF(UNIX)
		EXECUTE_PROCESS(COMMAND "date" ${GET_DATE_FORMAT} OUTPUT_VARIABLE CURRENT_DATE)
		STRING(REGEX REPLACE "\n$" "" CURRENT_DATE "${CURRENT_DATE}")
		message(DEBUG "GET_DATE_OUT value is ${GET_DATE_OUT}, assigning value ${CURRENT_DATE}")
		set(${GET_DATE_OUT} ${CURRENT_DATE} PARENT_SCOPE)
	ELSE()
		message(FATAL_ERROR "not implemented")
	ENDIF()

endfunction(get_current_date)

macro(setup_package)

	set(options)
	set(oneValueArgs NAME USER CHANNEL)
	set(multiValueArgs)

	cmake_parse_arguments(
		SETUP_PACKAGE 
		"${options}"
		"${oneValueArgs}" 
		"${multiValueArgs}" 
		${ARGN})

	string(TOUPPER ${SETUP_PACKAGE_NAME} UCASE)
	message(DEBUG "${SETUP_PACKAGE_NAME} package setup ...")

	# allows override of the user used
	if (NOT DEFINED SETUP_PACKAGE_USER)
		message(FATAL_ERROR "package ${SETUP_PACKAGE_NAME} user not set!")
	endif()

	if (NOT DEFINED SETUP_PACKAGE_CHANNEL)
		message(FATAL_ERROR "package ${SETUP_PACKAGE_NAME} channel not set!")
	endif()

	list(APPEND REPOS "${SETUP_PACKAGE_NAME}/${${UCASE}_VERS}@${SETUP_PACKAGE_USER}/${SETUP_PACKAGE_CHANNEL}")

endmacro()

function(append_global_property)

	set(options)
	set(oneValueArgs NAME )
	set(multiValueArgs VALUES)

	cmake_parse_arguments(
		APPEND_PROPERTY "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	get_property(TMP GLOBAL PROPERTY ${APPEND_PROPERTY_NAME})

	foreach(VAL ${APPEND_PROPERTY_VALUES})
		set(TMP "${TMP};${VAL}")
	endforeach()
	
	list(REMOVE_DUPLICATES TMP)
	message(DEBUG "Project components list updated to: ${TMP}")
	set_property(GLOBAL PROPERTY ${APPEND_PROPERTY_NAME} ${TMP})

endfunction(append_global_property)

function(load_debug_info)

	set(options)
	set(oneValueArgs)
	set(multiValueArgs NAME)

	cmake_parse_arguments(
		LOAD_DEBUG_INFO "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	message(DEBUG "load_debug_info function invoked with NAME ${LOAD_DEBUG_INFO_NAME}")

	foreach(PKG ${LOAD_DEBUG_INFO_NAME})

		string(TOUPPER ${PKG} PKG_NAME)
		set(PKG_PATH    "CONAN_USER_${PKG_NAME}_GDB_PRINTER_FOLDER" )
		set(PKG_FILE    "CONAN_USER_${PKG_NAME}_GDB_PRINTER_FILE"   )
		set(PKG_CLASSES "CONAN_USER_${PKG_NAME}_GDB_IMPORT_CLASSES" )
		set(PKG_PRINTER "CONAN_USER_${PKG_NAME}_GDB_PRINTER_CLASS"  )

		set(DEBUG_PATH ${CONAN_${PKG_NAME}_ROOT}/${${PKG_PATH}})

		if(DEFINED ${PKG_PATH} AND EXISTS ${DEBUG_PATH})
			message(DEBUG "found debug information in ${DEBUG_PATH} for package ${PKG}")
			set(${PKG_NAME}_GDB_FOLDER        ${DEBUG_PATH}		PARENT_SCOPE)
			set(${PKG_NAME}_GDB_FILE          ${${PKG_FILE}}    PARENT_SCOPE)
			set(${PKG_NAME}_GDB_CLASSES       ${${PKG_CLASSES}} PARENT_SCOPE)
			set(${PKG_NAME}_GDB_PRINTER_CLASS ${${PKG_PRINTER}}	PARENT_SCOPE)
		endif()
	endforeach()
endfunction()

macro(load_packages)

	# important: keep as a macro to fwd to calling scope
	set(options UPDATE)
	set(oneValueArgs PROFILE USER CHANNEL)
	set(multiValueArgs NAME OPTIONS SETTINGS)

	cmake_parse_arguments(
		LOAD_PACKAGES "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	# if USER or CHANNEL not set we follow conan API and retrieve from env
	# see https://docs.conan.io/en/latest/reference/conanfile/attributes.html#default-user-default-channel
	if (NOT DEFINED LOAD_PACKAGES_USER)
		set(LOAD_PACKAGES_USER "$ENV{CONAN_USERNAME}")
		message(DEBUG "retrieved conan user from environment: ${LOAD_PACKAGES_USER}")
	endif()

	if (NOT DEFINED LOAD_PACKAGES_CHANEL)
		set(LOAD_PACKAGES_CHANNEL "$ENV{CONAN_CHANNEL}")
		message(DEBUG "retrieved conan channel from environment: ${LOAD_PACKAGES_CHANNEL}")
	endif()

	foreach(PKG ${LOAD_PACKAGES_NAME})
		setup_package(NAME ${PKG} USER ${LOAD_PACKAGES_USER} CHANNEL ${LOAD_PACKAGES_CHANNEL})
	endforeach(PKG)

	message(STATUS "packages to be loaded: ${REPOS} with configuration ${CMAKE_BUILD_TYPE}, \
				settings ${LOAD_PACKAGES_SETTINGS} and options string ${LOAD_PACKAGES_OPTIONS}")

	IF (${LOAD_PACKAGES_UPDATE})
		conan_cmake_run(
			REQUIRES ${REPOS}
			OPTIONS ${LOAD_PACKAGES_OPTIONS}
			SETTINGS ${LOAD_PACKAGES_SETTINGS}
			PROFILE ${LOAD_PACKAGES_PROFILE}
			BASIC_SETUP CMAKE_TARGETS
			BASIC_SETUP KEEP_RPATHS
			BUILD missing
			BUILD_TYPE ${CMAKE_BUILD_TYPE}
			UPDATE ON
		)
	ELSE()
	conan_cmake_run(
		REQUIRES ${REPOS}
		OPTIONS ${LOAD_PACKAGES_OPTIONS}
		SETTINGS ${LOAD_PACKAGES_SETTINGS}
		PROFILE ${LOAD_PACKAGES_PROFILE}
		BASIC_SETUP CMAKE_TARGETS
		BASIC_SETUP KEEP_RPATHS
		BUILD missing
		BUILD_TYPE ${CMAKE_BUILD_TYPE}
	)
	ENDIF()

	conan_global_flags()

	foreach(PKG ${REPO})
		string(TOUPPER ${PKG} UCASE)
		if(${UCASE}_CMAKE_CONFIG)
			message(DEBUG "${UCASE}_CMAKE_CONFIG has been defined. Looking for ${PKG}Config.cmake...")
			find_package(${PKG} REQUIRED HINTS CONAN_${PKG}_ROOT)
			if (${${PKG}_FOUND})
				message(STATUS "${PKG} package ... Found")
			else()
				message(FATAL_ERROR "${PKG} package ... Not Found !")
			endif()
		endif()
	endforeach(PKG)
endmacro()

function(setup_component)

    set(options)
	set(oneValueArgs TARGET)
	set(multiValueArgs)

	cmake_parse_arguments(
		SETUP_COMPONENT 
		"${options}"
		"${oneValueArgs}" 
		"${multiValueArgs}" ${ARGN}
	)

endfunction()


# install the library in the standard lib path
function(install_library)

    set(options)
	set(oneValueArgs NAME PACKAGE)
	set(multiValueArgs HEADERS)

	cmake_parse_arguments(
		INSTALL_LIBRARY "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if (DEFINED INSTALL_LIBRARY_PACKAGE)
	else()
		set(INSTALL_LIBRARY_PACKAGE ${INSTALL_LIBRARY_NAME})
	endif()

	message(DEBUG "CMAKE_CURRENT_SOURCE_DIR set to ${CMAKE_CURRENT_SOURCE_DIR}")
	message(DEBUG "set ${INSTALL_LIBRARY_NAME} install path to ${INSTALL_LIBRARY_SUFFIX}")
	message(DEBUG "${INSTALL_LIBRARY_NAME} include files: ${INSTALL_INCLUDE_SUFFIX}")
	message(DEBUG "PROJECT_SOURCE_DIR set to: ${PROJECT_SOURCE_DIR}/${INSTALL_INCLUDE_SUFFIX}")
	message(DEBUG "INSTALL_LIBRARY_PACKAGE set to: ${INSTALL_LIBRARY_PACKAGE}")

	# create the headers with the correct path layout
	foreach(HEADER_FILE ${INSTALL_LIBRARY_HEADERS})
		
		file(RELATIVE_PATH REL ${CMAKE_CURRENT_SOURCE_DIR}/.. ${HEADER_FILE})
		message(DEBUG "${HEADER_FILE} relative path set to ${REL}")

		string(TOLOWER ${PROJECT_NAME} PATH_PROJECT_EXT)

		# ... and to the custom install location
		set(TARGET_INCLUDE_PATH "${INSTALL_INCLUDE_SUFFIX}/${REL}")
		message(DEBUG "header ${HEADER_FILE} path set to ${TARGET_INCLUDE_PATH}")

		# get the path component
		get_filename_component(FILE_DIR ${TARGET_INCLUDE_PATH} DIRECTORY)
		message(DEBUG "header ${HEADER_FILE} will be copied in ${CMAKE_INSTALL_PREFIX}/${FILE_DIR}")

		file(MAKE_DIRECTORY "${CMAKE_INSTALL_PREFIX}/${FILE_DIR}")
		install(FILES ${HEADER_FILE} DESTINATION "${CMAKE_INSTALL_PREFIX}/${FILE_DIR}")
	endforeach()

	message(DEBUG "exporting ${INSTALL_LIBRARY_NAME} lib into ${INSTALL_LIBRARY_PACKAGE}-targets...")

	# TODO: this will fail to package shared libs ...
	install(
 		TARGETS ${INSTALL_LIBRARY_NAME}
		EXPORT ${INSTALL_LIBRARY_PACKAGE}-targets
 		LIBRARY DESTINATION ${INSTALL_LIBRARY_SUFFIX}
 		ARCHIVE DESTINATION ${INSTALL_LIBRARY_SUFFIX}
		RUNTIME DESTINATION ${INSTALL_BINARY_SUFFIX}
 		COMPONENT ${${TARGET_NAME}_LIBRARY_PACKAGE}
 	)

endfunction()

function(install_binary)

	set(options)
	set(oneValueArgs BINARY TARGET PACKAGE SUBFOLDER)
	set(multiValueArgs)

	cmake_parse_arguments(
		INSTALL_BINARY
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	if (INSTALL_BINARY_PACKAGE)
	else()
		set(INSTALL_BINARY_PACKAGE Unspecified)
	endif()

	message(DEBUG "set ${INSTALL_BINARY_TARGET} install path to ${CMAKE_INSTALL_PREFIX}/${INSTALL_BINARY_SUFFIX}")
	message(DEBUG "adding target ${INSTALL_BINARY_TARGET} to component ${INSTALL_BINARY_PACKAGE}")
	message(DEBUG "INSTALL_BINARY_TARGET binary name set to ${INSTALL_BINARY_BINARY}")

	# add the component to the component list

	append_global_property(NAME ProjectComponents VALUES ${INSTALL_BINARY_PACKAGE})

	# set the binary directory
	set_target_properties(${INSTALL_BINARY_TARGET} PROPERTIES OUTPUT_NAME "${INSTALL_BINARY_BINARY}")

	install(
		TARGETS ${INSTALL_BINARY_TARGET}
		RUNTIME DESTINATION ${INSTALL_BINARY_SUFFIX}/${INSTALL_BINARY_SUBFOLDER}
		COMPONENT ${INSTALL_BINARY_PACKAGE}
	)

endfunction()

function(add_gtest)

  set(options INSTALL)
  set(oneValueArgs BINARY TARGET SUBFOLDER)
  set(multiValueArgs)

  cmake_parse_arguments(
    ADD_GTEST
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}" ${ARGN})

  message(DEBUG "ADD_GTEST_TARGET set to ${ADD_GTEST_TARGET}")
  message(DEBUG "ADD_GTEST_BINARY set to ${ADD_GTEST_BINARY}")

  gtest_add_tests(
    TARGET ${ADD_GTEST_TARGET}
  )

  # add the test binary to the installation folder
  if(ADD_GTEST_INSTALL)
	message(DEBUG "ADD_GTEST_INSTALL flag is ON")
    install_binary(BINARY ${ADD_GTEST_BINARY} TARGET ${ADD_GTEST_TARGET} SUBFOLDER ${ADD_GTEST_SUBFOLDER})
  endif()

endfunction()

macro(enable_testing)

	message(DEBUG "CONAN_GTEST_ROOT value set to ${CONAN_GTEST_ROOT}")
	if (DEFINED CONAN_GTEST_ROOT)
		include(GoogleTest)
	else()
	endif()

	message(DEBUG "enabling testing ...")
	_enable_testing()

endmacro()


function(add_py_unittest)

  set(options)
	set(oneValueArgs EXEC NAME CLASS FILE PYTHONPATH)
	set(multiValueArgs DEPENDS)

	cmake_parse_arguments(
		ADD_TEST_PY "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	add_test(
		NAME python.${ADD_TEST_PY_NAME}
		COMMAND ${ADD_TEST_PY_EXEC} -m unittest -v ${ADD_TEST_PY_FILE}.${ADD_TEST_PY_CLASS}.${ADD_TEST_PY_NAME}
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	)

	set_tests_properties(python.${ADD_TEST_PY_NAME}
		PROPERTIES ENVIRONMENT ""
		DEPENDS ${ADD_TEST_PY_DEPENDS}
	)

	set_property(TEST python.${ADD_TEST_PY_NAME}
		APPEND PROPERTY ENVIRONMENT "PYTHONPATH=${ADD_TEST_PY_PYTHONPATH}"
	)

endfunction(add_py_unittest)

macro(add_testsuite)

	set(options)
	set(oneValueArgs DIRECTORY)
	set(multiValueArgs)

	cmake_parse_arguments(
		ADD_TESTSUITE
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	message(DEBUG "enable testing...")

	enable_testing()

	# the CTest file cannot be imported before 
	# the project get defined... So we import it here !
	add_subdirectory(${ADD_TESTSUITE_DIRECTORY})

endmacro()

function(create_debug_conf)
    
	# utility function to create (if any) the 
	# gdb pretty print file associated with a lib/project
	set(options)
	set(oneValueArgs)
	set(multiValueArgs NAME)

	cmake_parse_arguments(
		CREATE_DEBUG_CONF "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	load_debug_info(
		NAME ${CREATE_DEBUG_CONF_NAME}
	)

	foreach(PKG ${CREATE_DEBUG_CONF_NAME})

		string(TOUPPER ${PKG} PKG_NAME)
		# if(linux)
		# create the .gdbinit file in local cache

		if (DEFINED ${PKG_NAME}_GDB_FOLDER)
			list(APPEND SYSPATHS "sys.path.insert(0, '${${PKG_NAME}_GDB_FOLDER}')\n")
		endif()

		if (DEFINED ${PKG_NAME}_GDB_FILE AND DEFINED ${PKG_NAME}_GDB_CLASSES)

		    string(REGEX REPLACE ".py" "" FOO ${${PKG_NAME}_GDB_FILE})
		    set(TMP "from ${FOO} import ${${PKG_NAME}_GDB_CLASSES}\n")
			list(APPEND IMPORTSTR ${TMP})
		endif()

		if (DEFINED ${PKG_NAME}_GDB_PRINTER_CLASS)
			list(APPEND REGISTERSTR "${${PKG_NAME}_GDB_PRINTER_CLASS}(None)\n")
		endif()

	endforeach()

	message(DEBUG "SYSPATHS string set to ${SYSPATHS}"		)
	message(DEBUG "IMPORTSTR string set to ${IMPORTSTR}"	)
	message(DEBUG "REGISTERSTR string set to ${REGISTERSTR}")

	# writing the .gdinit file
	file(WRITE "${PROJECT_BINARY_DIR}/.gdbinit"
	"python\nimport sys\n\n${SYSPATHS}\n${IMPORTSTR}\n${REGISTERSTR}\nend\n\nset print pretty on\nset print static-members on\n")

endfunction()

function(import_python)

	set(options)
	set(oneValueArgs HINT)
	set(multiValueArgs)

	cmake_parse_arguments(
		IMPORT_PYTHON
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	set(Python3_ROOT_DIR ${IMPORT_PYTHON_HINT})

	message(DEBUG "Python3_ROOT_DIR set to value: ${Python3_ROOT_DIR}")

	# include python libs
	find_package(
		Python3 REQUIRED
		COMPONENTS Interpreter Development
	)

	# set the python paths to python3
	message(DEBUG "Python3_PYTHONLIBS_FOUND set to value: ${Python3_PYTHONLIBS_FOUND}"		)
	message(DEBUG "Python3_EXECUTABLE set to value: ${Python3_EXECUTABLE}"					)
	message(DEBUG "Python3_LIBRARY_DIRS set to value: ${Python3_LIBRARY_DIRS}"				)
	message(DEBUG "Python3_INCLUDE_DIRS set to value: ${Python3_INCLUDE_DIRS}"				)
	message(DEBUG "PYTHONLIBS_VERSION_STRING set to value: ${PYTHONLIBS_VERSION_STRING}"	)

	set(PYTHONLIBS_FOUND			${Python3_PYTHONLIBS_FOUND} PARENT_SCOPE)
	set(PYTHON_EXECUTABLE			${Python3_EXECUTABLE}		PARENT_SCOPE)
	set(PYTHON_LIBRARIES_DIRS		${Python3_LIBRARY_DIRS}		PARENT_SCOPE)
	set(PYTHON_INCLUDE_PATH			${Python3_INCLUDE_DIRS}		PARENT_SCOPE)
	set(PYTHONLIBS_VERSION_STRING	${Python3_VERSION}			PARENT_SCOPE)

	message(DEBUG "PYTHON_EXECUTABLE set to location: ${PYTHON_EXECUTABLE}"				)

	message(DEBUG "PYTHONLIBS_FOUND set to value: ${PYTHONLIBS_FOUND}"						)
	message(DEBUG "PYTHON_LIBRARIES_DIRS set to location: ${PYTHON_LIBRARIES_DIRS}"			)
	message(DEBUG "PYTHON_INCLUDE_PATH set to location: ${PYTHON_INCLUDE_PATH}"				)
	message(DEBUG "PYTHONLIBS_VERSION_STRING set to location: ${PYTHONLIBS_VERSION_STRING}"	)

	include_directories(${PYTHON_INCLUDE_PATH})

endfunction()

function(export_project)

	set(options)
	set(oneValueArgs NAME NAMESPACE REVISION DIRECTORY)
	set(multiValueArgs)

	cmake_parse_arguments(
		EXPORT_PROJECT
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	message(DEBUG "exporting targets for project ${EXPORT_PROJECT_NAME} v${EXPORT_PROJECT_REVISION} in namespace ${EXPORT_PROJECT_NAMESPACE}")

	string(TOUPPER ${EXPORT_PROJECT_NAME} PROJECT_NAME_U)

	file(
		WRITE "${CMAKE_INSTALL_PREFIX}/${INSTALL_BINARY_SUFFIX}/${EXPORT_PROJECT_NAME}ConfigVersion.cmake"
		"set(PACKAGE_VERSION \"${EXPORT_PROJECT_REVISION}\")"
	)

	# generates the conan variables for the project
	file(
		WRITE "${CMAKE_INSTALL_PREFIX}/${INSTALL_BINARY_SUFFIX}/${EXPORT_PROJECT_NAME}Config.cmake"
		"set(${PROJECT_NAME_U}_CONAN_INCLUDE_DIRS_HINT ${CMAKE_INSTALL_PREFIX}/${INSTALL_INCLUDE_SUFFIX})\n"
        "set(${PROJECT_NAME_U}_CONAN_LIBS_DIRS_HINT ${CMAKE_INSTALL_PREFIX}/${INSTALL_LIBRARY_SUFFIX})\n"
        "set(${PROJECT_NAME_U}_CONAN_BINS_DIRS_HINT ${CMAKE_INSTALL_PREFIX}/${INSTALL_BINARY_SUFFIX})\n"
		"include(${CONAN_${PROJECT_NAME_U}_ROOT}/${PROJECT_NAME}Targets.cmake)\n"
	)
	
	# TODO: we need at least 1 target exported with the corresponding export
	# for the export to succeed. Hence a control or a warning may help here
	install(
		EXPORT ${EXPORT_PROJECT_NAME}-targets
		NAMESPACE "${EXPORT_PROJECT_NAMESPACE}::"
		FILE "${EXPORT_PROJECT_NAME}Targets.cmake"
		DESTINATION ${CMAKE_INSTALL_PREFIX}/${INSTALL_BINARY_SUFFIX}
		COMPONENT ${EXPORT_PROJECT_NAME}
	)

endfunction()

function(conan_export)

	set(options)
	set(oneValueArgs PACKAGE REVISION USER CHANNEL PROFILE DIRECTORY)
	set(multiValueArgs SETTINGS OPTIONS)

	cmake_parse_arguments(
		CONAN_EXPORT
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	add_custom_target(conan-package ALL)

	message(DEBUG "CONAN_EXPORT_DIRECTORY set to ${CONAN_EXPORT_DIRECTORY}")

	set(CONAN_PACKAGE_STR "${CONAN_EXPORT_PACKAGE}/${CONAN_EXPORT_REVISION}@${CONAN_EXPORT_USER}/${CONAN_EXPORT_CHANNEL}")
	message(STATUS "CONAN_PACKAGE_STR for project ${PROJECT_NAME} package has been set to ${CONAN_PACKAGE_STR}")
	
	# parse the conan command
	foreach(FLAG ${CONAN_EXPORT_SETTINGS})
		set(CONAN_FLAG_STR "${CONAN_FLAG_STR} -s ${FLAG}")
	endforeach()

	message(DEBUG "CONAN_FLAG_STR set to ${CONAN_FLAG_STR}")

	foreach(FLAG ${CONAN_EXPORT_OPTIONS})
		set(CONAN_OPTS_STR "${CONAN_OPTS_STR} -o ${FLAG}")
	endforeach()

	install(CODE "message(STATUS \"execute command ${CONAN_BIN_PATH}/conan export-pkg . ${CONAN_PACKAGE_STR} -f -pr=${CONAN_EXPORT_PROFILE} -s build_type=${CMAKE_BUILD_TYPE} ${CONAN_FLAG_STR} ${CONAN_OPTS_STR} --source-folder=${PROJECT_HOME} --build-folder=${PROJECT_BINARY_DIR} WORKING_DIRECTORY ${PROJECT_HOME}/${CONAN_EXPORT_DIRECTORY}\" )")
	install(CODE "execute_process(COMMAND ${CONAN_BIN_PATH}/conan export-pkg . ${CONAN_PACKAGE_STR} -f -pr=${CONAN_EXPORT_PROFILE} -s build_type=${CMAKE_BUILD_TYPE} ${CONAN_FLAG_STR} ${CONAN_OPTS_STR} --source-folder=${PROJECT_HOME} --build-folder=${PROJECT_BINARY_DIR} WORKING_DIRECTORY ${PROJECT_HOME}/${CONAN_EXPORT_DIRECTORY} )")

endfunction()

function(package_binaries)

	# TODO: add project name, version
	set(options)
	set(oneValueArgs CONTACT VENDOR PREFIX HOMEPAGE CHANNEL)
	set(multiValueArgs)

	cmake_parse_arguments(
		PACKAGE_BINARIES
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	message(DEBUG "invoking function package_binaries")
	message(DEBUG "PACKAGE_BINARIES_PREFIX set to ${PACKAGE_BINARIES_PREFIX}")

	# cpack setup
	set(CPACK_RPM_COMPONENT_INSTALL ON)																	# Enables Component Packaging
	set(CPACK_COMPONENTS_IGNORE_GROUPS 1)																# ignore groups for now on
	set(CPACK_GENERATOR "RPM")
	set(CPACK_PACKAGE_VERSION ${${PROJECT_NAME_U}_MAJOR_VERSION}.${${PROJECT_NAME_U}_MINOR_VERSION})	# package version will show up as 0.1-71774 in yum
	set(CPACK_RPM_PACKAGE_RELEASE ${${PROJECT_NAME_U}_BUILD_VERSION})
	set(CPACK_PACKAGE_CONTACT ${PACKAGE_BINARIES_CONTACT})
	set(CPACK_PACKAGE_VENDOR ${PACKAGE_BINARIES_VENDOR})
	set(CPACK_PACKAGING_INSTALL_PREFIX "${PACKAGE_BINARIES_PREFIX}/${${PROJECT_NAME_U}_VERSION}")
	set(CMAKE_PROJECT_HOMEPAGE_URL ${PACKAGE_BINARIES_HOMEPAGE})

	# prevent rpmbuild from stripping binaries when in debug mode
	# ref: https://iangilham.com/2016/12/08/preventing-rpmbuild-stripping-symbols-with-cpack.html
	if(CMAKE_BUILD_TYPE STREQUAL "Debug")
	  set(CPACK_RPM_SPEC_INSTALL_POST "/bin/true")
	endif()

	get_property(tmp GLOBAL PROPERTY ProjectComponents)

	string(TOLOWER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_LC)

	list(REMOVE_ITEM tmp "Unspecified")

	foreach(COMPONENT ${tmp})

		message(DEBUG "add cpack attributes for component ${COMPONENT}")

		set(CPACK_RPM_${COMPONENT}_FILE_NAME "${COMPONENT}-${${PROJECT_NAME_U}_VERSION}-${CMAKE_BUILD_TYPE_LC}-${CMAKE_ARCH}.rpm")
		
		message(DEBUG "CPACK_RPM_${COMPONENT}_FILE_NAME srt to ${CPACK_RPM_${COMPONENT}_FILE_NAME}")

		set(CPACK_RPM_${COMPONENT}_PACKAGE_NAME "${COMPONENT}-${CMAKE_BUILD_TYPE_LC}-${CMAKE_ARCH}")
		
		# create the post install script in root ...
		set(POST_INSTALL_FILE "${PROJECT_BINARY_DIR}/deployment/${COMPONENT}-${${PROJECT_NAME_U}_VERSION}-${CMAKE_BUILD_TYPE_LC}-${CMAKE_ARCH}.rpm.post")
		
		message(DEBUG "package binary suffix set to ${INSTALL_BINARY_SUFFIX}")
		message(DEBUG "POST_INSTALL_FILE path set to ${POST_INSTALL_FILE}")
		
		file(WRITE ${POST_INSTALL_FILE}
			"mkdir -p ${PACKAGE_BINARIES_PREFIX}/${INSTALL_BINARY_SUFFIX} \nrm -Rf ${PACKAGE_BINARIES_PREFIX}/${INSTALL_BINARY_SUFFIX}/${COMPONENT} \nln -s ${PACKAGE_BINARIES_PREFIX}/${${PROJECT_NAME_U}_VERSION}/${INSTALL_BINARY_SUFFIX}/${COMPONENT} ${PACKAGE_BINARIES_PREFIX}/${INSTALL_BINARY_SUFFIX}/${COMPONENT}")

		# ... and attach it to the rpm
		set(CPACK_RPM_${COMPONENT}_POST_INSTALL_SCRIPT_FILE ${POST_INSTALL_FILE})

		# TODO: add those in install flags
		# CPACK_RPM_<component>_PACKAGE_SUMMARY -> description

		# other available flags: see https://cmake.org/cmake/help/v3.15/cpack_gen/rpm.html#cpack_gen:CPack%20RPM%20Generator

	endforeach()

	# cpack invocation
	set(CPACK_COMPONENTS_ALL ${tmp})
	include(CPack)

endfunction()

# the target subfolders must be defined here
if (NOT DEFINED INSTALL_BINARY_SUFFIX)
  set(INSTALL_BINARY_SUFFIX bin/${CMAKE_BUILD_TYPE} CACHE PATH "the binary install subfolder")
  message(WARN "INSTALL_BINARY_SUFFIX was not set. Defaulting to ${INSTALL_BINARY_SUFFIX}")
else()
  message(DEBUG "INSTALL_BINARY_SUFFIX set to ${INSTALL_BINARY_SUFFIX}")
endif()

file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/${INSTALL_BINARY_SUFFIX})

if (NOT DEFINED INSTALL_LIBRARY_SUFFIX)
  set(INSTALL_LIBRARY_SUFFIX lib/${CMAKE_BUILD_TYPE} CACHE PATH "the library install subfolder")
  message(WARN "INSTALL_LIBRARY_SUFFIX was not set. Defaulting to ${INSTALL_LIBRARY_SUFFIX}")
else()
  message(DEBUG "INSTALL_LIBRARY_SUFFIX set to ${INSTALL_LIBRARY_SUFFIX}")
endif()

file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/${INSTALL_LIBRARY_SUFFIX})

if (NOT DEFINED INSTALL_INCLUDE_SUFFIX)
  set(INSTALL_INCLUDE_SUFFIX include CACHE PATH "the binary install subfolder")
  message(WARN "INSTALL_INCLUDE_SUFFIX was not set. Defaulting to ${INSTALL_INCLUDE_SUFFIX}")
else()
  message(DEBUG "INSTALL_INCLUDE_SUFFIX set to ${INSTALL_INCLUDE_SUFFIX}")
endif()

file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/${INSTALL_INCLUDE_SUFFIX})

######################
# R related function #
######################

# add a packaged test (test_that) to the test suite
function(add_r_test)

    set(options)
	set(oneValueArgs MODULE FILE WORKING_DIRECTORY)
	set(multiValueArgs)

	cmake_parse_arguments(
		ADD_R_TEST "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	string(CONCAT CMD
		"res <- as.data.frame(devtools::test(filter='${ADD_R_TEST_FILE}'))\;"
        "quit(status = (sum(res$failed) + sum(res$error) + sum(res$skipped) != 0))"
	)

	add_test(NAME ${ADD_R_TEST_MODULE}.r.test.${ADD_R_TEST_FILE}
		COMMAND ${R_EXEC} -e ${CMD}
		WORKING_DIRECTORY ${ADD_R_TEST_WORKING_DIRECTORY}
	)

endfunction()
