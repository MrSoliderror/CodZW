#include <STDInclude.hpp>

namespace Assets
{
	void IMaterialVertexDeclaration::Save(Game::XAssetHeader header, Components::ZoneBuilder::Zone* builder)
	{
		Assert_Size(Game::MaterialVertexDeclaration, 100);

		Utils::Stream* buffer = builder->GetBuffer();
		Game::MaterialVertexDeclaration* asset = header.vertexDecl;
		Game::MaterialVertexDeclaration* dest = buffer->Dest<Game::MaterialVertexDeclaration>();
		buffer->Save(asset);

		buffer->PushBlock(Game::XFILE_BLOCK_VIRTUAL);

		if (asset->name)
		{
			buffer->SaveString(builder->GetAssetName(this->GetType(), asset->name));
			Utils::Stream::ClearPointer(&dest->name);
		}

		buffer->PopBlock();
	}
}
