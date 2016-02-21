-- Option to allow copying the DLL file to a custom folder after build
newoption {
	trigger = "copy-to",
	description = "Optional, copy the DLL to a custom folder after build, define the path here if wanted.",
	value = "PATH"
}

newoption {
	trigger = "no-new-structure",
	description = "Do not use new virtual path structure (separating headers and source files)."
}

newaction {
	trigger = "version",
	description = "Returns the version string for the current commit of the source code.",
	onWorkspace = function(wks)
		-- get revision number via git
		local proc = assert(io.popen("git rev-list --count HEAD", "r"))
		local revNumber = assert(proc:read('*a')):gsub("%s+", "")
		proc:close()

		print(revNumber)
		os.exit(0)
	end
}

newaction {
	trigger = "generate-buildinfo",
	description = "Sets up build information file like version.h.",
	onWorkspace = function(wks)
		-- get revision number via git
		local proc = assert(io.popen("git rev-list --count HEAD", "r"))
		local revNumber = assert(proc:read('*a')):gsub("%s+", "")
		proc:close()

		-- get old version number from version.hpp if any
		local oldRevNumber = "(none)"
		local oldVersionHeader = io.open(wks.location .. "/src/version.hpp", "r")
		if oldVersionHeader ~=nil then
			local oldVersionHeaderContent = assert(oldVersionHeader:read('*a'))
			oldRevNumber = string.match(oldVersionHeaderContent, "#define REVISION (%d+)")
			if oldRevNumber == nil then
				-- old version.hpp format?
				oldRevNumber = "(none)"
			end
		end

		-- generate version.hpp with a revision number if not equal
		if oldRevNumber ~= revNumber then
			print ("Update " .. oldRevNumber .. " -> " .. revNumber)
			local versionHeader = assert(io.open(wks.location .. "/src/version.hpp", "w"))
			versionHeader:write("/*\n")
			versionHeader:write(" * Automatically generated by premake5.\n")
			versionHeader:write(" * Do not touch, you fucking moron!\n")
			versionHeader:write(" */\n")
			versionHeader:write("\n")
			versionHeader:write("#define REVISION " .. revNumber .. "\n")
			versionHeader:close()
		end
	end
}

workspace "iw4x"
	location "./build"
	objdir "%{wks.location}/obj"
	targetdir "%{wks.location}/bin/%{cfg.buildcfg}"
	configurations { "Debug", "DebugStatic", "Release", "ReleaseStatic" }
	architecture "x32"
	platforms "x86"

	-- VS 2015 toolset only
	toolset "msc-140"

	configuration "windows"
		defines { "_WINDOWS", "WIN32" }

	configuration "Release*"
		defines { "NDEBUG" }
		flags { "MultiProcessorCompile", "Symbols", "LinkTimeOptimization", "No64BitChecks" }
		optimize "Full"

	configuration "Debug*"
		defines { "DEBUG", "_DEBUG" }
		flags { "MultiProcessorCompile", "Symbols", "No64BitChecks" }
		optimize "Debug"

	configuration "*Static"
		flags { "StaticRuntime" }

	project "iw4x"
		kind "SharedLib"
		language "C++"
		files {
			"./src/**.hpp",
			"./src/**.cpp",
			"./src/**.proto",
		}
		includedirs {
			"%{prj.location}/src",
			"./src"
		}

		-- Pre-compiled header
		pchheader "STDInclude.hpp" -- must be exactly same as used in #include directives
		pchsource "src/STDInclude.cpp" -- real path
		buildoptions { "/Zm100 -Zm100" }
		filter "files:**.pb.*"
			flags {
				"NoPCH",
			}
			buildoptions {
				"/wd4100", -- "Unused formal parameter"
				"/wd6011", -- "Dereferencing NULL pointer"
				"/wd4125", -- "Decimal digit terminates octal escape sequence"
			}
			defines {
				"_SCL_SECURE_NO_WARNINGS",
			}
		filter {}

		-- Dependency libraries
		links { "zlib", "json11", "pdcurses", "libtomcrypt", "libtommath", "protobuf" }
		includedirs 
		{
			"./deps/zlib",
			"./deps/json11", 
			"./deps/pdcurses", 
			"./deps/asio/asio/include",
			"./deps/libtomcrypt/src/headers",
			"./deps/libtommath",
			"./deps/protobuf/src",
			"./deps/Wink-Signals",
		}
		
		-- fix vpaths for protobuf sources
		vpaths {
			["*"] = { "./src/**" },
			["Proto/Generated"] = { "**.pb.*" }, -- meh.
		}

		-- Virtual paths
		if not _OPTIONS["no-new-structure"] then
			vpaths {
				["Headers/*"] = { "./src/**.hpp" },
				["Sources/*"] = { "./src/**.cpp" },
				["Proto/Definitions/*"] = { "./src/Proto/**.proto" },
				["Proto/Generated/*"] = { "**.pb.*" }, -- meh.
			}
		end

		vpaths {
			["Docs/*"] = { "**.txt","**.md" },
		}
		
		-- Pre-build
		prebuildcommands {
			"cd %{_MAIN_SCRIPT_DIR}",
			"tools\\premake5 generate-buildinfo"
		}

		-- Post-build
		if _OPTIONS["copy-to"] then
			saneCopyToPath = string.gsub(_OPTIONS["copy-to"] .. "\\", "\\\\", "\\")
			postbuildcommands {
				"copy /y \"$(TargetDir)*.dll\" \"" .. saneCopyToPath .. "\""
			}
		end

		-- Specific configurations
		flags { "UndefinedIdentifiers", "ExtraWarnings" }

		configuration "Release*"
			flags { "FatalCompileWarnings" }
		configuration {}

		-- Generate source code from protobuf definitions
		rules { "ProtobufCompiler" }

		-- Workaround: Consume protobuf generated source files
		matches = os.matchfiles(path.join("src/Proto/**.proto"))
		for i, srcPath in ipairs(matches) do
			basename = path.getbasename(srcPath)
			files {
				string.format("%%{prj.location}/src/proto/%s.pb.h", basename),
				string.format("%%{prj.location}/src/proto/%s.pb.cc", basename),
			}
		end
		includedirs {
			"%{prj.location}/src/proto"
		}

	group "External dependencies"

		-- zlib
		project "zlib"
			language "C"
			defines { "ZLIB_DLL", "_CRT_SECURE_NO_DEPRECATE" }

			files
			{
				"./deps/zlib/*.h",
				"./deps/zlib/*.c"
			}

			-- not our code, ignore POSIX usage warnings for now
			warnings "Off"

			kind "SharedLib"
			configuration "*Static"
				kind "StaticLib"
				removedefines { "ZLIB_DLL" }
				
				
		-- json11
		project "json11"
			language "C++"

			files
			{
				"./deps/json11/*.cpp",
				"./deps/json11/*.hpp"
			}
			
			-- remove dropbox's testing code
			removefiles { "./deps/json11/test.cpp" }

			-- not our code, ignore POSIX usage warnings for now
			warnings "Off"

			-- always build as static lib, as json11 doesn't export anything
			kind "StaticLib"
			
			
		-- pdcurses
		project "pdcurses"
			language "C"
			includedirs { "./deps/pdcurses/"  }

			files
			{
				"./deps/pdcurses/pdcurses/*.c",
				"./deps/pdcurses/win32/*.c"
			}

			-- not our code, ignore POSIX usage warnings for now
			warnings "Off"

			-- always build as static lib, as pdcurses doesn't export anything
			kind "StaticLib"

		-- libtomcrypt
		project "libtomcrypt"
			language "C"
			defines { "_LIB", "LTC_SOURCE", "LTC_NO_FAST", "LTC_NO_RSA_BLINDING", "LTM_DESC", "USE_LTM", "WIN32" }
			
			links { "libtommath" }
			includedirs { "./deps/libtomcrypt/src/headers"  }
			includedirs { "./deps/libtommath"  }

			files { "./deps/libtomcrypt/src/**.c" }
			
			-- seems like tab stuff can be omitted
			removefiles { "./deps/libtomcrypt/src/**/*tab.c" }
			
			-- remove incorrect files
			-- for some reason, they lack the necessary header files
			-- i might have to open a pull request which includes them
			removefiles 
			{ 
				"./deps/libtomcrypt/src/pk/dh/dh_sys.c",
				"./deps/libtomcrypt/src/hashes/sha2/sha224.c",
				"./deps/libtomcrypt/src/hashes/sha2/sha384.c",
				"./deps/libtomcrypt/src/encauth/ocb3/**.c",
			}

			-- not our code, ignore POSIX usage warnings for now
			warnings "Off"

			-- always build as static lib, as libtomcrypt doesn't export anything
			kind "StaticLib"
			
		-- libtommath
		project "libtommath"
			language "C"
			defines { "_LIB" }
			includedirs { "./deps/libtommath"  }

			files { "./deps/libtommath/*.c" }

			-- not our code, ignore POSIX usage warnings for now
			warnings "Off"

			-- always build as static lib, as libtommath doesn't export anything
			kind "StaticLib"
			
		-- protobuf
		project "protobuf"
			language "C++"
			links { "zlib" }
			defines { "_SCL_SECURE_NO_WARNINGS" }
			includedirs 
			{ 
				"./deps/zlib",
				"./deps/protobuf/src",
			}

			-- default protobuf sources
			files { "./deps/protobuf/src/**.cc" }

			-- remove unnecessary sources
			removefiles 
			{ 
				"./deps/protobuf/src/**/*test.cc",
				"./deps/protobuf/src/google/protobuf/*test*.cc",
				
				"./deps/protobuf/src/google/protobuf/testing/**.cc",
				"./deps/protobuf/src/google/protobuf/compiler/**.cc",
				
				"./deps/protobuf/src/google/protobuf/arena_nc.cc",
				"./deps/protobuf/src/google/protobuf/util/internal/error_listener.cc",
				"./deps/protobuf/src/google/protobuf/stubs/atomicops_internals_x86_gcc.cc",
			}

			-- not our code, ignore POSIX usage warnings for now
			warnings "Off"

			-- always build as static lib, as we include our custom classes and therefore can't perform shared linking
			kind "StaticLib"

rule "ProtobufCompiler"
	display "Protobuf compiler"
	location "./build"
	fileExtension ".proto"
	buildmessage "Compiling %(Identity) with protoc..."
	buildcommands {
		'@echo off',
		'path "$(SolutionDir)\\..\\tools"',
		'if not exist "$(ProjectDir)\\src\\proto" mkdir "$(ProjectDir)\\src\\proto"',
		'protoc --error_format=msvs -I=%(RelativeDir) --cpp_out=src\\proto %(Identity)',
	}
	buildoutputs {
		'$(ProjectDir)\\src\\proto\\%(Filename).pb.cc',
		'$(ProjectDir)\\src\\proto\\%(Filename).pb.h',
	}
