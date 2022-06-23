#pragma once

namespace Components
{
	class Playlist : public Component
	{
	public:
		typedef void(*Callback)();

		Playlist();

		static void LoadPlaylist();

		static std::string ReceivedPlaylistBuffer;

	private:
		static std::string CurrentPlaylistBuffer;
		static std::unordered_map<const void*, std::string> MapRelocation;

		static DWORD StorePlaylistStub(const char** buffer);

		static void PlaylistRequest(const Network::Address& address, const std::string& data);
		static void PlaylistReponse(const Network::Address& address, const std::string& data);
		static void PlaylistInvalidPassword(const Network::Address& address, const std::string& data);

		static void MapNameCopy(char *dest, const char *src, int destsize);
		static void SetMapName(const char* cvar, const char* value);
		static int GetMapIndex(const char* mapname);
	};
}
