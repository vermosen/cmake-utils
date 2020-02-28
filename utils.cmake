cmake_minimum_required (VERSION 3.13)

include_guard(GLOBAL)

message(STATUS   "\n")
message(STATUS   ":===================:")
message(STATUS   ":loading utils.cmake:")
message(STATUS   ":===================:\n")

# message function override
function(message)
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

function(get_current_date)

    # usage 
    #SET(CURRENT_DATE "")
    #get_current_date(
    #    OUT CURRENT_DATE
    #    FORMAT "+%Y-%m-%d"
    #)

    SET(options)
	SET(oneValueArgs OUT FORMAT)
	SET(multiValueArgs)

	cmake_parse_arguments(
		GET_DATE "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	MESSAGE(DEBUG "GET_DATE_OUT value is ${GET_DATE_OUT}")

	IF(UNIX)
		EXECUTE_PROCESS(COMMAND "date" ${GET_DATE_FORMAT} OUTPUT_VARIABLE CURRENT_DATE)
		STRING(REGEX REPLACE "\n$" "" CURRENT_DATE "${CURRENT_DATE}")
		MESSAGE(DEBUG "GET_DATE_OUT value is ${GET_DATE_OUT}, assigning value ${CURRENT_DATE}")
		SET(${GET_DATE_OUT} ${CURRENT_DATE} PARENT_SCOPE)
	ELSE()
		MESSAGE(FATAL_ERROR "not implemented")
	ENDIF()

endfunction(get_current_date)

macro(setup_package)

    SET(options)
	SET(oneValueArgs NAME)
	SET(multiValueArgs)

	cmake_parse_arguments(
		SETUP_PACKAGE 
		"${options}"
		"${oneValueArgs}" 
		"${multiValueArgs}" 
		${ARGN})

	STRING(TOUPPER ${SETUP_PACKAGE_NAME} UCASE)

	MESSAGE(DEBUG "${SETUP_PACKAGE_NAME} package setup ...")

	# allows override of the user used
	IF(DEFINED ${UCASE}_CONAN_USER)
		MESSAGE(STATUS "${libname} user has been overriden to ${${UCASE}_CONAN_USER}")
	else()
		SET(${UCASE}_CONAN_USER ${CONAN_USER})
	endif()

	# allows override of the channel used
	IF(DEFINED ${UCASE}_CONAN_CHANNEL)
		MESSAGE(STATUS "${libname} channel has been overriden to ${${UCASE}_CONAN_CHANNEL}")
	else()
		SET(${UCASE}_CONAN_CHANNEL ${CONAN_CHANNEL})
	endif()

	list(APPEND REPOS "${SETUP_PACKAGE_NAME}/${${UCASE}_VERS}@${${UCASE}_CONAN_USER}/${${UCASE}_CONAN_CHANNEL}")

endmacro()

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
		set(PKG_PATH "CONAN_USER_${PKG_NAME}_GDB_PRINTER")

		message(DEBUG "gdb variable set to ${PKG_PATH} with value ${${PKG_PATH}}")
		message(DEBUG "root folder set to CONAN_${PKG_NAME}_ROOT with value ${CONAN_${PKG_NAME}_ROOT}")

		if(DEFINED ${PKG_PATH})
			set(GDB_PATH "${CONAN_${PKG_NAME}_ROOT}/${${PKG_PATH}}")

			message(DEBUG "pretty printer path set to ${GDB_PATH}")

			if(EXISTS ${GDB_PATH})
				SET(${PKG_NAME}_PRETTY_PRINTER ${GDB_PATH} PARENT_SCOPE)
			else()
				message(WARNING "cannot find defined path ${GDB_PATH}")
			endif()
		endif()
	endforeach()
endfunction()

function(load_packages)

    SET(options UPDATE)
	SET(oneValueArgs PROFILE OPTIONS SETTINGS)
	SET(multiValueArgs NAME)

	cmake_parse_arguments(
		LOAD_PACKAGES "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	foreach(PKG ${LOAD_PACKAGES_NAME})
		setup_package(NAME ${PKG})
	endforeach(PKG)

	MESSAGE(STATUS "packages to be loaded: ${REPOS} with configuration ${CMAKE_BUILD_TYPE}, settings ${LOAD_PACKAGES_SETTINGS} and options string ${LOAD_PACKAGES_OPTIONS}")

	IF (${LOAD_PACKAGES_UPDATE})
		conan_cmake_run(
			REQUIRES ${REPOS}
			OPTIONS ${LOAD_PACKAGES_OPTIONS}
			SETTINGS ${LOAD_PACKAGES_SETTINGS}
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
			MESSAGE(DEBUG "${UCASE}_CMAKE_CONFIG has been defined. Looking for ${PKG}Config.cmake...")
			find_package(${PKG} REQUIRED HINTS CONAN_${PKG}_ROOT)
			if (${${PKG}_FOUND})
				MESSAGE(STATUS "${PKG} package ... Found")
			else()
				MESSAGE(FATAL_ERROR "${PKG} package ... Not Found !")
			endif()
		endif()
	endforeach(PKG)
endfunction()

function(setup_component)

    SET(options)
	SET(oneValueArgs TARGET)
	SET(multiValueArgs)

	cmake_parse_arguments(
		SETUP_COMPONENT 
		"${options}"
		"${oneValueArgs}" 
		"${multiValueArgs}" ${ARGN}
	)

	MESSAGE(DEBUG "setting target library ${SETUP_COMPONENT_TARGET}")

	set(TARGET_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)
	MESSAGE(DEBUG "${SETUP_COMPONENT_TARGET} source folder set to ${TARGET_SOURCE_DIR}")

	GET_PROPERTY(TMP GLOBAL PROPERTY ProjectTargets)
	SET(TMP "${TMP};${SETUP_COMPONENT_TARGET}")
	MESSAGE(DEBUG "ProjectTargets values: ${TMP}")
	SET_PROPERTY(GLOBAL PROPERTY ProjectTargets "${TMP}")
endfunction()


# install the library in the standard lib path
function(install_library)

    SET(options)
	SET(oneValueArgs NAME)
	SET(multiValueArgs)

	cmake_parse_arguments(
		INSTALL_LIBRARY "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	MESSAGE(DEBUG "set ${INSTALL_LIBRARY_NAME} install path to ${PROJECT_LIB_SUFFIX}")
	MESSAGE(DEBUG "${INSTALL_LIBRARY_NAME} include files: ${PROJECT_INCLUDE_SUFFIX}")
	MESSAGE(DEBUG "PROJECT_SOURCE_DIR value is ${PROJECT_SOURCE_DIR}")

	# create the headers with the correct path layout
	foreach(HEADER_FILE ${PUBLIC_HEADERS})
		file(RELATIVE_PATH REL "${PROJECT_SOURCE_DIR}" ${HEADER_FILE})
		string(TOLOWER ${PROJECT_NAME} PATH_PROJECT_EXT)

		# ... and to the custom install location
		SET(TARGET_INCLUDE_PATH "${PROJECT_INCLUDE_SUFFIX}/${REL}")
		MESSAGE(DEBUG "${HEADER_FILE} target full path is ${TARGET_INCLUDE_PATH}")

		# get the path component
		get_filename_component(FILE_DIR ${TARGET_INCLUDE_PATH} DIRECTORY)
		MESSAGE(DEBUG "header ${HEADER_FILE} will be copied in ${FILE_DIR}")

		file(MAKE_DIRECTORY "${FILE_DIR}/${LIB_INSTALL_PREFIX}")
		install(FILES ${HEADER_FILE} DESTINATION "${FILE_DIR}/${LIB_INSTALL_PREFIX}")
	endforeach()

	MESSAGE(DEBUG "exporting ${INSTALL_LIBRARY_NAME} lib into ${${TARGET_NAME}_LIBRARY_PACKAGE}}-targets...")

	INSTALL(
 		TARGETS ${INSTALL_LIBRARY_NAME}
		EXPORT "${${INSTALL_LIBRARY_NAME}_LIBRARY_PACKAGE}-targets"
 		LIBRARY DESTINATION ${PROJECT_LIB_SUFFIX}
 		ARCHIVE DESTINATION ${PROJECT_LIB_SUFFIX}
		RUNTIME DESTINATION ${PROJECT_BIN_SUFFIX}
 		COMPONENT ${${TARGET_NAME}_LIBRARY_PACKAGE}
 	)

endfunction()

function(install_binary)

	SET(options)
	SET(oneValueArgs NAME TARGET COMPONENT)
	SET(multiValueArgs)

	cmake_parse_arguments(
		INSTALL_BINARY
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	if (INSTALL_BINARY_COMPONENT)
	else()
		SET(INSTALL_BINARY_COMPONENT Unspecified)
	endif()

	# add the component to the component list
	#GET_PROPERTY(tmp GLOBAL PROPERTY ProjectComponents)
	#SET(tmp "${tmp};${INSTALL_BINARY_PACKAGE}")
	#list(REMOVE_DUPLICATES tmp)
	#MESSAGE(DEBUG "Project components is set to: ${tmp}")
	#SET_PROPERTY(GLOBAL PROPERTY ProjectComponents "${tmp}")

	MESSAGE(DEBUG "set ${INSTALL_BINARY_TARGET} install path to ${CMAKE_INSTALL_PREFIX}/bin")
	MESSAGE(DEBUG "adding target ${TARGET_NAME} to package ${INSTALL_BINARY_PACKAGE}")
	MESSAGE(DEBUG "${TARGET_NAME} binary name set to ${BINARY_NAME}")

	set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME "${BINARY_NAME}")

	INSTALL(
		TARGETS ${TARGET_NAME}
		RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/bin/${TARGET_INSTALL_SUBFOLDER}"
		COMPONENT ${INSTALL_BINARY_COMPONENT}
	)

endfunction()

function(add_gtest)

  SET(options)
  SET(oneValueArgs TARGET SUBFOLDER)
  SET(multiValueArgs)

  cmake_parse_arguments(
    ADD_GTEST
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}" ${ARGN})

  MESSAGE(DEBUG "test TARGET set to ${ADD_GTEST_TARGET}")

  gtest_add_tests(
    TARGET ${ADD_GTEST_TARGET}
  )

  install_binary(TARGET ${ADD_GTEST_TARGET} SUBFOLDER ${ADD_GTEST_SUBFOLDER})

endfunction()

macro(enable_testing)

	MESSAGE(DEBUG "CONAN_GTEST_ROOT value set to ${CONAN_GTEST_ROOT}")
	if (DEFINED CONAN_GTEST_ROOT)
		include(GoogleTest)
	else()
	endif()

	MESSAGE(DEBUG "enabling testing ...")
	_enable_testing()

endmacro()

function(import_python)

	SET(options)
	SET(oneValueArgs HINT)
	SET(multiValueArgs)

	cmake_parse_arguments(
		IMPORT_PYTHON
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	SET(Python3_ROOT_DIR ${IMPORT_PYTHON_HINT})

	MESSAGE(DEBUG "Python3_ROOT_DIR set to value: ${Python3_ROOT_DIR}")

	# include python libs
	find_package(
		Python3 REQUIRED
		COMPONENTS Interpreter Development
	)

	# set the python paths to python3
	MESSAGE(DEBUG "Python3_PYTHONLIBS_FOUND set to value: ${Python3_PYTHONLIBS_FOUND}"		)
	MESSAGE(DEBUG "Python3_EXECUTABLE set to value: ${Python3_EXECUTABLE}"					)
	MESSAGE(DEBUG "Python3_LIBRARY_DIRS set to value: ${Python3_LIBRARY_DIRS}"				)
	MESSAGE(DEBUG "Python3_INCLUDE_DIRS set to value: ${Python3_INCLUDE_DIRS}"				)
	MESSAGE(DEBUG "PYTHONLIBS_VERSION_STRING set to value: ${PYTHONLIBS_VERSION_STRING}"	)

	SET(PYTHONLIBS_FOUND			${Python3_PYTHONLIBS_FOUND} PARENT_SCOPE)
	SET(PYTHON_EXECUTABLE			${Python3_EXECUTABLE}		PARENT_SCOPE)
	SET(PYTHON_LIBRARIES_DIRS		${Python3_LIBRARY_DIRS}		PARENT_SCOPE)
	SET(PYTHON_INCLUDE_PATH			${Python3_INCLUDE_DIRS}		PARENT_SCOPE)
	SET(PYTHONLIBS_VERSION_STRING	${Python3_VERSION}			PARENT_SCOPE)

	MESSAGE(MESSAGE "PYTHON_EXECUTABLE set to location: ${PYTHON_EXECUTABLE}"				)

	MESSAGE(DEBUG "PYTHONLIBS_FOUND set to value: ${PYTHONLIBS_FOUND}"						)
	MESSAGE(DEBUG "PYTHON_LIBRARIES_DIRS set to location: ${PYTHON_LIBRARIES_DIRS}"			)
	MESSAGE(DEBUG "PYTHON_INCLUDE_PATH set to location: ${PYTHON_INCLUDE_PATH}"				)
	MESSAGE(DEBUG "PYTHONLIBS_VERSION_STRING set to location: ${PYTHONLIBS_VERSION_STRING}"	)

	include_directories(${PYTHON_INCLUDE_PATH})

endfunction()