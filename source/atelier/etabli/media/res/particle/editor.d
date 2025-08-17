module atelier.etabli.media.res.particle.editor;

import std.file;
import std.path;
import std.math : abs;

import farfadet;
import atelier;

import atelier.etabli.ui;
import atelier.etabli.media.res.base;
import atelier.etabli.media.res.editor;
import atelier.etabli.media.res.entity_render;
import atelier.etabli.media.res.particle.parameter;
import atelier.etabli.media.res.particle.player;
import atelier.etabli.media.res.particle.source;

final class ParticleResourceEditor : ResourceBaseEditor {
    private {
        Farfadet _ffd;
        string _name;
        ParameterWindow _parameterWindow;
        MediaPlayer _player;

        EntityRenderData[] _renders;
        HitboxData _hitbox;
        ParticleData _particle;

        Vec2f _originPosition = Vec2f.zero;
        float _zoom = 1f;

        EditorParticleSource _source;
    }

    this(ResourceEditor editor, string path_, Farfadet ffd, Vec2f size) {
        super(editor, path_, ffd, size);
        _ffd = ffd;

        _name = ffd.get!string(0);

        _hitbox.load(ffd);
        _particle.load(ffd);

        foreach (size_t i, Farfadet renderNode; ffd.getNodes("render")) {
            EntityRenderData render = new EntityRenderData(renderNode);
            render.isVisible = (i == 0);
            _renders ~= render;
        }

        _source = new EditorParticleSource(this);

        _parameterWindow = new ParameterWindow(_renders, _hitbox, _particle);

        _player = new MediaPlayer();
        _player.setRenders(_renders);
        addUI(_player);

        _parameterWindow.addEventListener("property_hitbox", {
            _hitbox = _parameterWindow.getHitbox();
            setDirty();
        });

        _parameterWindow.addEventListener("property_particle", {
            _particle = _parameterWindow.getParticle();
            _source.setData(_particle);
            setDirty();
        });

        _parameterWindow.addEventListener("property_render", {
            _renders.length = 0;
            foreach (size_t i, EntityRenderData renderData; _parameterWindow.getRenders()) {
                EntityRenderData render = new EntityRenderData(renderData);
                render.isVisible = (i == _player.getRender());
                _renders ~= render;
            }
            _player.setRenders(_renders);
            _source.setGraphics(_renders);
            setDirty();
        });

        _player.addEventListener("particle_graphic", {
            //foreach (size_t i, EntityRenderData render; _renders) {
            //    render.isVisible = (i == _player.getRender());
            //}
            //_source.setGraphics(_renders);
        });

        _player.addEventListener("particle_start", { _source.start(); });
        _player.addEventListener("particle_stop", { _source.stop(); });
        _player.addEventListener("particle_emit", { _source.emit(); });
        _player.addEventListener("particle_clear", { _source.clear(); });

        addEventListener("update", &_onUpdate);
        addEventListener("draw", &_onDraw);
        addEventListener("wheel", &_onWheel);
        addEventListener("mousedown", &_onMouseDown);
        addEventListener("mouseup", &_onMouseUp);
        addEventListener("mouseleave", {
            removeEventListener("mousemove", &_onDrag);
        });
        addEventListener("size", { _player.setWidth(getWidth()); });

        _source.setGraphics(_renders);
        _source.setData(_particle);

    }

    override Farfadet save(Farfadet ffd) {
        Farfadet node = ffd.addNode("particle").add(_name);
        foreach (EntityRenderData render; _renders) {
            render.save(node);
        }
        _hitbox.save(node);
        _particle.save(node);
        return node;
    }

    override UIElement getPanel() {
        return _parameterWindow;
    }

    private void _onMouseDown() {
        InputEvent.MouseButton ev = getManager().input.asMouseButton();
        switch (ev.button) with (InputEvent.MouseButton.Button) {
        case right:
            addEventListener("mousemove", &_onDrag);
            break;
        default:
            break;
        }
    }

    private void _onMouseUp() {
        InputEvent.MouseButton ev = getManager().input.asMouseButton();
        switch (ev.button) with (InputEvent.MouseButton.Button) {
        case right:
            removeEventListener("mousemove", &_onDrag);
            break;
        default:
            break;
        }
    }

    private void _onDrag() {
        UIManager manager = getManager();
        InputEvent.MouseMotion ev = manager.input.asMouseMotion();
        _originPosition += ev.deltaPosition;
    }

    private void _onWheel() {
        UIManager manager = getManager();
        InputEvent.MouseWheel ev = manager.input.asMouseWheel();
        float zoomDelta = 1f + (ev.wheel.sum() * 0.25f);

        Vec2f mouseOffset = getMousePosition() - getCenter();
        Vec2f delta = (mouseOffset - _originPosition) / _zoom;
        _zoom *= zoomDelta;
        Vec2f delta2 = (mouseOffset - _originPosition) / _zoom;

        _originPosition += (delta2 - delta) * _zoom;
    }

    private void _onUpdate() {
        _source.update();

        if (_player.isRunning() && !_source.isRunning()) {
            _player.stop();
        }
    }

    private void _onDraw() {
        _source.draw(getCenter());
    }
}
