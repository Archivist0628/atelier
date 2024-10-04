/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module atelier.render.tilemap;

import std.conv : to;
import std.exception : enforce;
import std.math : floor, ceil;
import std.algorithm.comparison : min, max;

import atelier.common;
import atelier.core;
import atelier.scene;
import atelier.render.image;
import atelier.render.tileset;

final class Tilemap : Image, Resource!Tilemap {
    private {
        struct Tile {
            short id;
            short elevation;
        }

        Tileset _tileset;
        uint _currentTick;
        Tile[] _tiles;
        uint _columns, _lines;
    }

    Vec2f size = Vec2f.zero;

    @property {
        uint columns() const {
            return _columns;
        }

        uint lines() const {
            return _lines;
        }

        Vec2f mapSize() const {
            return (cast(Vec2f) _tileset.tileSize) * Vec2f(columns, lines);
        }

        Vec2f tileSize() const {
            return size / Vec2f(_columns, _lines);
        }
    }

    this(Tileset tileset, uint columns, uint lines) {
        _tileset = tileset;
        _columns = columns;
        _lines = lines;
        clip = _tileset.clip;

        size = (cast(Vec2f) _tileset.tileSize) * Vec2f(_columns, _lines);

        _tiles.length = _columns * _lines;
        foreach (ref Tile tile; _tiles) {
            tile.id = -1;
            tile.elevation = 0;
        }
    }

    this(Tilemap tilemap) {
        super(tilemap);
        _tileset = tilemap._tileset;
        _columns = tilemap._columns;
        _lines = tilemap._lines;
        _tiles = tilemap._tiles.dup;
        size = tilemap.size;
    }

    /// Accès à la ressource
    Tilemap fetch() {
        return new Tilemap(this);
    }

    void setDimensions(uint columns_, uint lines_) {
        int[][] tiles_ = getTiles();
        _lines = lines_;
        _columns = columns_;
        _tiles.length = _columns * _lines;
        setTiles(0, 0, tiles_);
    }

    int getTile(int x, int y) {
        if (x < 0 || y < 0 || x >= _columns || y >= _lines)
            return -1;

        return _tiles[x + y * _columns].id;
    }

    void setTile(int x, int y, int tile) {
        if (x < 0 || y < 0 || x >= _columns || y >= _lines)
            return;

        _tiles[x + y * _columns].id = cast(short) tile;
    }

    int getTileElevation(int x, int y) {
        if (x < 0 || y < 0 || x >= _columns || y >= _lines)
            return -1;

        return _tiles[x + y * _columns].elevation;
    }

    void setTileElevation(int x, int y, int elevation) {
        if (x < 0 || y < 0 || x >= _columns || y >= _lines)
            return;

        _tiles[x + y * _columns].elevation = cast(short) elevation;
    }

    void setTiles(const(int[][]) tiles_) {
        enforce(tiles_.length == _lines, "taille des tuiles invalides: " ~ to!string(
                tiles_.length) ~ " lignes au lieu de " ~ to!string(_lines));
        foreach (size_t y, ref const(int[]) line; tiles_) {
            enforce(line.length == _columns, "taille des tuiles invalides: " ~ to!string(
                    tiles_.length) ~ " colonnes au lieu de " ~ to!string(
                    _columns) ~ " à la ligne " ~ to!string(y));
            foreach (size_t x, int tileId; line) {
                _tiles[x + y * _columns].id = cast(short) tileId;
            }
        }
    }

    int[][] getTiles() {
        int[][] tiles = new int[][](_columns, _lines);

        for (size_t y; y < _lines; ++y) {
            for (size_t x; x < _columns; ++x) {
                tiles[x][y] = _tiles[x + y * _columns].id;
            }
        }

        return tiles;
    }

    void setTiles(int x, int y, const(int[][]) tiles_) {
        foreach (size_t col, ref const(int[]) column; tiles_) {
            if ((col + x) >= _columns || (col + x) < 0)
                continue;

            foreach (size_t ln, int tileId; column) {
                if ((ln + y) >= _lines || (ln + y) < 0)
                    continue;

                _tiles[(col + x) + (ln + y) * _columns].id = cast(short) tileId;
            }
        }
    }

    void setTilesElevation(const(int[][]) tiles_) {
        enforce(tiles_.length == _lines, "taille des tuiles invalides: " ~ to!string(
                tiles_.length) ~ " lignes au lieu de " ~ to!string(_lines));
        foreach (size_t y, ref const(int[]) line; tiles_) {
            enforce(line.length == _columns, "taille des tuiles invalides: " ~ to!string(
                    tiles_.length) ~ " colonnes au lieu de " ~ to!string(
                    _columns) ~ " à la ligne " ~ to!string(y));
            foreach (size_t x, int elevation; line) {
                _tiles[x + y * _columns].elevation = cast(short) elevation;
            }
        }
    }

    /// Redimensionne l’image pour qu’elle puisse tenir dans une taille donnée
    override void fit(Vec2f size_) {
        size = mapSize.fit(size_);
    }

    /// Redimensionne l’image pour qu’elle puisse contenir une taille donnée
    override void contain(Vec2f size_) {
        size = mapSize.contain(size_);
    }

    override void update() {
        _currentTick++;
        if (_currentTick >= _tileset.frameTime) {
            _currentTick = 0;
            foreach (ref Tile tile; _tiles) {
                tile.id = _tileset.getTileFrame(tile.id);
            }
        }
    }

    override void draw(Vec2f origin = Vec2f.zero) {
        _tileset.color = color;
        _tileset.alpha = alpha;
        _tileset.blend = blend;

        /*Vec2f finalTileSize = ((cast(Vec2f) _tileset.tileSize) * tileSize) / cast(Vec2f) _tileset
            .clip.zw;*/
        //Vec2f mapSize = tileSize * Vec2f(_columns, _lines);
        Vec2f finalTileSize = size / Vec2f(_columns, _lines);
        Vec2f ratio = size / mapSize();
        Vec2f finalClipSize = (cast(Vec2f) _tileset.clip.zw) * ratio;
        import std.stdio;

        Vec2f startPos = origin + position - size * anchor;
        //writeln(finalTileSize);
        Vec2f tilePos;

        if (_tileset.isIsometric) {
            Vec2f halfTile = finalTileSize / 2f;

            for (int y; y < _lines; y++) {
                for (int x; x < _columns; x++) {
                    tilePos = startPos;
                    tilePos.x += (x - y) * halfTile.x;
                    tilePos.y += (x + y) * halfTile.y;

                    int tileId = _tiles[x + y * _columns].id;
                    int elevation = _tiles[x + y * _columns].elevation;
                    tilePos.y -= elevation;

                    if (tileId >= 0)
                        _tileset.draw(tileId, tilePos, finalClipSize, angle);
                }
            }
        }
        else {
            int minX = 0;
            int minY = 0;
            int maxX = _columns;
            int maxY = _lines;

            /*if (Atelier.scene.isOnScene) {
                Vec4f cameraClip = Atelier.scene.cameraClip;
                minX = max(0, cast(int) floor((cameraClip.x - startPos.x) / tileSize.x));
                minY = max(0, cast(int) floor((cameraClip.y - startPos.y) / tileSize.y));
                maxX = min(_columns, cast(int) ceil((cameraClip.z - startPos.x) / tileSize.x));
                maxY = min(_lines, cast(int) ceil((cameraClip.w - startPos.y) / tileSize.y));
            }*/

            for (int y = minY; y < maxY; y++) {
                for (int x = minX; x < maxX; x++) {
                    tilePos = startPos;
                    tilePos.x += x * finalTileSize.x;
                    tilePos.y += y * finalTileSize.y;

                    int tileId = _tiles[x + y * _columns].id;
                    int elevation = _tiles[x + y * _columns].elevation;
                    tilePos.y -= elevation;

                    if (tileId >= 0)
                        _tileset.draw(tileId, tilePos, finalClipSize, angle);
                }
            }
        }
    }
}
