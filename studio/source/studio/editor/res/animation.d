/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module studio.editor.res.animation;

import std.array : split;
import std.conv : to, ConvException;
import std.file;
import std.path;
import std.math : abs;
import atelier;
import farfadet;
import studio.editor.res.base;
import studio.project;
import studio.ui;

final class AnimationResourceEditor : ResourceBaseEditor {
    private {
        Farfadet _ffd;
        string _name;
        string _textureRID;
        Vec4u _clip;
        uint _columns, _lines, _maxCount;
        Vec2i _margin;
        int[] _frames;
        bool _repeat, _hasMaxCount;
        uint _frameTime;
        Vec2u _imageSize;
        Vec2f _position = Vec2f.zero;
        Texture _texture;
        Sprite _sprite;
        float _zoom = 1f;
        Vec2f _positionMouse = Vec2f.zero;
        Vec2f _deltaMouse = Vec2f.zero;
        Vec2i _clipAnchor, _clipAnchor2;
        bool _isResizingVertical;
        Toolbox _toolbox;
        ParameterWindow _parameterWindow;
        int _tool;
    }

    this(string path_, Farfadet ffd, Vec2f size) {
        super(path_, size);
        _ffd = ffd;

        _name = ffd.get!string(0);

        if (ffd.hasNode("texture")) {
            _textureRID = ffd.getNode("texture").get!string(0);
        }

        if (ffd.hasNode("clip")) {
            _clip = ffd.getNode("clip").get!Vec4u(0);
        }

        if (ffd.hasNode("frameTime")) {
            _frameTime = ffd.getNode("frameTime").get!uint(0);
        }

        if (ffd.hasNode("frames")) {
            _frames = ffd.getNode("frames").get!(int[])(0);
        }

        if (ffd.hasNode("repeat")) {
            _repeat = ffd.getNode("repeat").get!bool(0);
        }

        if (ffd.hasNode("columns")) {
            _columns = ffd.getNode("columns").get!int(0);
        }

        if (ffd.hasNode("lines")) {
            _lines = ffd.getNode("lines").get!int(0);
        }

        if (ffd.hasNode("maxCount")) {
            _hasMaxCount = true;
            _maxCount = ffd.getNode("maxCount").get!int(0);
        }
        else {
            _maxCount = _lines * _columns;
        }

        if (ffd.hasNode("margin")) {
            _margin = ffd.getNode("margin").get!Vec2i(0);
        }

        setTextureRID(_textureRID);

        _parameterWindow = new ParameterWindow(_textureRID, _clip, _columns,
            _lines, _hasMaxCount, _maxCount, _margin, _repeat, _frameTime, _frames);

        _toolbox = new Toolbox();
        _toolbox.setTexture(getTexture(), _clip, _columns, _lines, _maxCount);
        _toolbox.setParameters(_frameTime, _frames, _columns, _lines, _maxCount, _margin);
        Atelier.ui.addUI(_toolbox);

        _parameterWindow.addEventListener("property_textureRID", {
            _textureRID = _parameterWindow.getTextureRID();
            setTextureRID(_textureRID);
            _toolbox.setTexture(getTexture(), _clip, _columns, _lines, _maxCount);
            _toolbox.setParameters(_frameTime, _frames, _columns, _lines,
                _hasMaxCount ? _maxCount : (_columns * _lines), _margin);
        });

        _parameterWindow.addEventListener("property_clip", {
            _clip = _parameterWindow.getClip();
            _toolbox.setClip(_clip);
        });

        _parameterWindow.addEventListener("property_misc", {
            _parameterWindow.getMisc(_columns, _lines, _hasMaxCount, _maxCount,
                _margin, _repeat, _frameTime, _frames);
            _toolbox.setParameters(_frameTime, _frames, _columns, _lines,
                _hasMaxCount ? _maxCount : (_columns * _lines), _margin);
        });

        addEventListener("clip", {
            _parameterWindow.setClip(_clip);
            _toolbox.setClip(_clip);
        });
        _toolbox.addEventListener("tool", { _tool = _toolbox.getTool(); });
        addEventListener("register", { Atelier.ui.addUI(_toolbox); });
        addEventListener("unregister", { _toolbox.remove(); });
    }

    override Farfadet save(Farfadet ffd) {
        Farfadet node = ffd.addNode("sprite");
        node.add(_name);
        node.addNode("texture").add(_textureRID);
        node.addNode("clip").add(_clip);
        return node;
    }

    override UIElement getPanel() {
        return _parameterWindow;
    }

    void setTextureRID(string rid) {
        bool mustLoad = _texture is null;
        _zoom = 1f;

        if (_sprite) {
            _sprite.remove();
        }

        auto info = Studio.getResource("texture", rid);
        string path = info.farfadet.getNode("file").get!string(0);
        _texture = Texture.fromFile(info.getPath(path));
        _imageSize = Vec2u(_texture.width, _texture.height);
        _sprite = new Sprite(_texture);
        addImage(_sprite);

        if (mustLoad) {
            addEventListener("update", &_onUpdate);
            addEventListener("draw", &_onDraw);
            addEventListener("wheel", &_onWheel);
            addEventListener("mousedown", &_onMouseDown);
            addEventListener("mouseup", &_onMouseUp);
            addEventListener("mouseleave", &_onMouseLeave);
            addEventListener("clickoutside", &_onMouseLeave);
        }
    }

    private void _onUpdate() {
        _sprite.position = getCenter() + _position;
    }

    Texture getTexture() {
        return _texture;
    }

    private void _onMouseLeave() {
        _positionMouse = Vec2f.zero;
        _deltaMouse = Vec2f.zero;
        removeEventListener("mousemove", &_onDrag);
        removeEventListener("mousemove", &_onMakeSelection);
        removeEventListener("mousemove", &_onMoveSelection);
        removeEventListener("mousemove", &_onMoveCorner);
        removeEventListener("mousemove", &_onMoveSide);
    }

    private void _onMouseDown() {
        InputEvent.MouseButton ev = getManager().input.asMouseButton();
        switch (ev.button) with (InputEvent.MouseButton.Button) {
        case right:
            addEventListener("mousemove", &_onDrag);
            break;
        case left:
            switch (_tool) {
            case 0:
                _positionMouse = (getMousePosition() - (_sprite.position - _sprite.size / 2f)) / _zoom;
                addEventListener("mousemove", &_onMakeSelection);
                break;
            case 1:
                Vec4f clip = _zoom * cast(Vec4f) _clip;
                Vec2f origin = _sprite.position - _sprite.size / 2f + clip.xy;
                if (getMousePosition().isBetween(origin, origin + clip.zw)) {
                    addEventListener("mousemove", &_onMoveSelection);
                }
                break;
            case 2:
                Vec2f positionMouse = (getMousePosition() - (_sprite.position - _sprite.size / 2f)) / _zoom;
                bool isResizingRight = positionMouse.x >= (_clip.x + _clip.z / 2f);
                bool isResizingBottom = positionMouse.y >= (_clip.y + _clip.w / 2f);

                _clipAnchor.x = _clip.x + (isResizingRight ? 0 : _clip.z);
                _clipAnchor.y = _clip.y + (isResizingBottom ? 0 : _clip.w);

                addEventListener("mousemove", &_onMoveCorner);
                break;
            case 3:
                Vec2f positionMouse = (getMousePosition() - (_sprite.position - _sprite.size / 2f)) / _zoom;
                bool isResizingRight = positionMouse.x >= (_clip.x + _clip.z / 2f);
                bool isResizingBottom = positionMouse.y >= (_clip.y + _clip.w / 2f);

                Vec2f delta = Vec2f.zero;
                delta.x = positionMouse.x - cast(float)(_clip.x + (isResizingRight ? _clip.z : 0));
                delta.y = positionMouse.y - cast(float)(_clip.y + (isResizingBottom ? _clip.w : 0));

                _isResizingVertical = abs(delta.y) < abs(delta.x);

                if (_isResizingVertical) {
                    if (isResizingBottom) {
                        _clipAnchor = Vec2i(_clip.x, _clip.y);
                        _clipAnchor2 = Vec2i(_clip.x + _clip.z, _clip.y);
                    }
                    else {
                        _clipAnchor = Vec2i(_clip.x, _clip.y + _clip.w);
                        _clipAnchor2 = Vec2i(_clip.x + _clip.z, _clip.y + _clip.w);
                    }
                }
                else {
                    if (isResizingRight) {
                        _clipAnchor = Vec2i(_clip.x, _clip.y);
                        _clipAnchor2 = Vec2i(_clip.x, _clip.y + _clip.w);
                    }
                    else {
                        _clipAnchor = Vec2i(_clip.x + _clip.z, _clip.y);
                        _clipAnchor2 = Vec2i(_clip.x + _clip.z, _clip.y + _clip.w);
                    }
                }
                addEventListener("mousemove", &_onMoveSide);
                break;
            default:
                break;
            }
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
        case left:
            switch (_tool) {
            case 0:
                removeEventListener("mousemove", &_onMakeSelection);
                _positionMouse = Vec2f.zero;
                break;
            case 1:
                removeEventListener("mousemove", &_onMoveSelection);
                _deltaMouse = Vec2f.zero;
                break;
            case 2:
                removeEventListener("mousemove", &_onMoveCorner);
                break;
            case 3:
                removeEventListener("mousemove", &_onMoveSide);
                break;
            default:
                break;
            }
            break;
        default:
            break;
        }
    }

    private void _onMakeSelection() {
        Vec2f endPositionMouse = (getMousePosition() - (_sprite.position - _sprite.size / 2f)) / _zoom;

        Vec2f startClip = _positionMouse.min(endPositionMouse).floor();
        Vec2f endClip = _positionMouse.max(endPositionMouse).ceil();

        startClip = startClip.clamp(Vec2f.zero, cast(Vec2f) _imageSize);
        endClip = endClip.clamp(Vec2f.zero, cast(Vec2f) _imageSize);

        Vec4u clip = Vec4u(cast(uint) startClip.x, cast(uint) startClip.y,
            cast(uint)(endClip.x - startClip.x), cast(uint)(endClip.y - startClip.y));

        if (clip != _clip) {
            _clip = clip;
            dispatchEvent("clip", false);
        }
    }

    private void _onMoveSelection() {
        InputEvent.MouseMotion ev = getManager().input.asMouseMotion();
        _deltaMouse += ev.deltaPosition / _zoom;

        Vec2i move = cast(Vec2i) _deltaMouse;

        if (move.x < 0 && _clip.x < -move.x) {
            move.x = -_clip.x;
        }
        else if (move.x > 0 && _clip.x + _clip.z + move.x > _imageSize.x) {
            move.x = _imageSize.x - (_clip.x + _clip.z);
        }

        if (move.y < 0 && _clip.y < -move.y) {
            move.y = -_clip.y;
        }
        else if (move.y > 0 && _clip.y + _clip.w + move.y > _imageSize.y) {
            move.y = _imageSize.y - (_clip.y + _clip.w);
        }

        _deltaMouse -= cast(Vec2f) move;
        _clip.xy = cast(Vec2u)((cast(Vec2i) _clip.xy) + move);

        if (move != Vec2i.zero) {
            dispatchEvent("clip", false);
        }
    }

    private void _onMoveCorner() {
        Vec2f mousePosition = (getMousePosition() - (_sprite.position - _sprite.size / 2f)) / _zoom;
        mousePosition = mousePosition.clamp(Vec2f.zero, cast(Vec2f) _imageSize);
        Vec2i corner = cast(Vec2i) mousePosition;

        Vec4i rect;
        rect.xy = corner.min(_clipAnchor);
        rect.zw = corner.max(_clipAnchor);

        Vec4u clip;
        clip.xy = cast(Vec2u) rect.xy;
        clip.zw = cast(Vec2u)(rect.zw - rect.xy);

        if (clip != _clip) {
            _clip = clip;
            dispatchEvent("clip", false);
        }
    }

    private void _onMoveSide() {
        Vec2f mousePosition = (getMousePosition() - (_sprite.position - _sprite.size / 2f)) / _zoom;
        mousePosition = mousePosition.clamp(Vec2f.zero, cast(Vec2f) _imageSize);
        Vec2i point = cast(Vec2i) mousePosition;

        Vec4u clip;
        if (_isResizingVertical) {
            clip.x = min(_clipAnchor.x, _clipAnchor2.x);
            clip.z = max(_clipAnchor.x, _clipAnchor2.x) - clip.x;
            clip.y = min(point.y, _clipAnchor.y);
            clip.w = max(point.y, _clipAnchor.y) - clip.y;
        }
        else {
            clip.x = min(point.x, _clipAnchor.x);
            clip.z = max(point.x, _clipAnchor.x) - clip.x;
            clip.y = min(_clipAnchor.y, _clipAnchor2.y);
            clip.w = max(_clipAnchor.y, _clipAnchor2.y) - clip.y;
        }

        if (clip != _clip) {
            _clip = clip;
            dispatchEvent("clip", false);
        }
    }

    private void _onDrag() {
        UIManager manager = getManager();
        InputEvent.MouseMotion ev = manager.input.asMouseMotion();
        _position += ev.deltaPosition;
    }

    private void _onDraw() {
        Vec2f origin = _sprite.position - _sprite.size / 2f;
        Vec4f clip = _zoom * cast(Vec4f) _clip;

        Atelier.renderer.drawRect(origin, _sprite.size, Atelier.theme.onNeutral, 1f, false);

        uint maxCount = _hasMaxCount ? _maxCount : (_columns * _lines);

        Color startFrameColor = Atelier.theme.accent;
        HSLColor hsl = HSLColor.fromColor(startFrameColor);
        hsl.h = hsl.h + 120f;
        Color currentFrameColor = hsl.toColor();
        hsl.h = hsl.h + 120f;
        Color otherFrameColor = hsl.toColor();

        uint frame;
        __gridLoop: for (uint y; y < _lines; ++y) {
            for (uint x; x < _columns; ++x) {
                if (frame >= maxCount) {
                    break __gridLoop;
                }

                Vec2f animClip = Vec2f(x, y) * (clip.zw + cast(Vec2f) _margin);

                Color color;
                if (frame == _toolbox._animation.frameId) {
                    color = currentFrameColor;

                    drawText(origin + clip.xy + Vec2f(clip.z - 12f,
                            clip.w - 2f) + animClip, to!dstring(_toolbox._animation.frame),
                        Atelier.theme.font, 1f, currentFrameColor);
                }
                else if (frame == 0) {
                    color = startFrameColor;
                }
                else {
                    color = otherFrameColor;
                }

                drawText(origin + clip.xy + Vec2f(2f, clip.w - 2f) + animClip,
                    to!dstring(frame), Atelier.theme.font, 1f, color);
                Atelier.renderer.drawRect(origin + clip.xy + animClip, clip.zw, color, 1f, false);

                frame++;
            }
        }
    }

    private void _onWheel() {
        UIManager manager = getManager();
        InputEvent.MouseWheel ev = manager.input.asMouseWheel();
        float zoomDelta = 1f + (ev.wheel.sum() * 0.25f);
        _zoom *= zoomDelta;
        _sprite.size = (cast(Vec2f) _sprite.clip.zw) * _zoom;
        Vec2f delta = _sprite.position - getMousePosition();
        _sprite.position = delta * zoomDelta + getMousePosition();
    }
}

private class Toolbox : Modal {
    private {
        Animation _animation;
        ToolGroup _toolGroup;
        Label _frameCountLabel, _frameIdLabel;
        int _tool;
    }

    this() {
        setSize(Vec2f(200f, 300f));
        setAlign(UIAlignX.left, UIAlignY.top);
        setPosition(Vec2f(258f, 75f));

        {
            Label title = new Label("Outils", Atelier.theme.font);
            title.setAlign(UIAlignX.center, UIAlignY.top);
            title.setPosition(Vec2f(0f, 8f));
            addUI(title);
        }

        {
            HBox hbox = new HBox;
            hbox.setAlign(UIAlignX.center, UIAlignY.top);
            hbox.setPosition(Vec2f(0f, 32f));
            hbox.setSpacing(4f);
            addUI(hbox);

            _toolGroup = new ToolGroup;
            foreach (key; ["selection", "move", "corner", "side"]) {
                ToolButton btn = new ToolButton(_toolGroup,
                    "editor:" ~ key ~ "-button", key == "selection");
                btn.setSize(Vec2f(32f, 32f));
                hbox.addUI(btn);
            }
        }

        {
            Rectangle rect = Rectangle.outline(Vec2f.one * (getWidth() - 16f), 1f);
            rect.color = Atelier.theme.onNeutral;
            rect.anchor = Vec2f(0.5f, 1f);
            rect.position = Vec2f(getCenter().x, getHeight() - 8f);
            addImage(rect);

            _frameIdLabel = new Label("0", Atelier.theme.font);
            _frameIdLabel.setAlign(UIAlignX.right, UIAlignY.bottom);
            _frameIdLabel.setPosition(Vec2f(10f, 10f));
            _frameIdLabel.textColor = Atelier.theme.accent;
            addUI(_frameIdLabel);

            _frameCountLabel = new Label("0", Atelier.theme.font);
            _frameCountLabel.setAlign(UIAlignX.right, UIAlignY.bottom);
            _frameCountLabel.setPosition(Vec2f(10f, 12f + _frameIdLabel.getHeight()));
            _frameCountLabel.textColor = Atelier.theme.onNeutral;
            addUI(_frameCountLabel);
        }

        addEventListener("update", {
            if (_toolGroup.value != _tool) {
                _tool = _toolGroup.value;
                dispatchEvent("tool", false);
            }
            _frameIdLabel.text = to!string(_animation.frameId);
            _frameCountLabel.text = to!string(_animation.frame);
        });
    }

    int getTool() const {
        return _toolGroup.value();
    }

    void setTexture(Texture texture, Vec4u clip, uint columns, uint lines, uint maxCount) {
        if (_animation)
            _animation.remove();
        _animation = new Animation(texture, clip, columns, lines, maxCount);
        _animation.repeat = true;
        _animation.anchor = Vec2f(0.5f, 1f);
        _animation.position = Vec2f(getCenter().x, getHeight() - 8f);
        _animation.fit(Vec2f.one * (getWidth() - 16f));
        addImage(_animation);
    }

    void setClip(Vec4u clip) {
        if (_animation)
            _animation.clip = clip;
    }

    void setParameters(uint frameTime, int[] frames, uint columns, uint lines,
        uint maxCount, Vec2i margin) {
        _animation.frameTime = frameTime;
        _animation.frames = frames;
        _animation.columns = columns;
        _animation.lines = lines;
        _animation.maxCount = maxCount;
        _animation.margin = margin;
    }
}

private final class ParameterWindow : UIElement {
    private {
        SelectButton _textureSelect;
        IntegerField[] _clipFields, _marginFields, _countFields;
        TextField _framesField;
        IntegerField _frameTimeField;
        Checkbox _repeatCB, _hasMaxCountCB;
    }

    this(string textureRID, Vec4u clip, uint columns, uint lines, bool hasMaxCount,
        uint maxCount, Vec2i margin, bool repeat, uint frameTime, int[] frames) {
        VList vlist = new VList;
        vlist.setPosition(Vec2f(8f, 8f));
        vlist.setSize(Vec2f.zero.max(getSize() - Vec2f(8f, 8f)));
        vlist.setAlign(UIAlignX.left, UIAlignY.top);
        vlist.setColor(Atelier.theme.surface);
        vlist.setSpacing(8f);
        vlist.setChildAlign(UIAlignX.left);
        addUI(vlist);

        {
            LabelSeparator sep = new LabelSeparator("Propriétés", Atelier.theme.font);
            sep.setColor(Atelier.theme.neutral);
            sep.setPadding(Vec2f(284f, 0f));
            sep.setSpacing(8f);
            sep.setLineWidth(1f);
            vlist.addList(sep);
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vlist.addList(hlayout);

            hlayout.addUI(new Label("Texture:", Atelier.theme.font));

            _textureSelect = new SelectButton(Studio.getResourceList("texture"), textureRID);
            _textureSelect.setWidth(200f);
            _textureSelect.addEventListener("value", {
                dispatchEvent("property_textureRID", false);
            });
            hlayout.addUI(_textureSelect);
        }

        {
            LabelSeparator sep = new LabelSeparator("Région", Atelier.theme.font);
            sep.setColor(Atelier.theme.neutral);
            sep.setPadding(Vec2f(284f, 0f));
            sep.setSpacing(8f);
            sep.setLineWidth(1f);
            vlist.addList(sep);
        }

        {
            foreach (field; ["Position X", "Position Y", "Largeur", "Hauteur"]) {
                IntegerField numField = new IntegerField();
                numField.setMinValue(0);
                numField.addEventListener("value", {
                    dispatchEvent("property_clip", false);
                });
                _clipFields ~= numField;

                HLayout hlayout = new HLayout;
                hlayout.setPadding(Vec2f(284f, 0f));
                vlist.addList(hlayout);

                hlayout.addUI(new Label(field ~ ":", Atelier.theme.font));
                hlayout.addUI(numField);
            }

            _clipFields[0].value = clip.x;
            _clipFields[1].value = clip.y;
            _clipFields[2].value = clip.z;
            _clipFields[3].value = clip.w;
        }

        {
            foreach (field; ["Marge X", "Marge Y"]) {
                IntegerField numField = new IntegerField();
                numField.addEventListener("value", {
                    dispatchEvent("property_misc", false);
                });
                _marginFields ~= numField;

                HLayout hlayout = new HLayout;
                hlayout.setPadding(Vec2f(284f, 0f));
                vlist.addList(hlayout);

                hlayout.addUI(new Label(field ~ ":", Atelier.theme.font));
                hlayout.addUI(numField);
            }

            _marginFields[0].value = margin.x;
            _marginFields[1].value = margin.y;
        }

        {
            LabelSeparator sep = new LabelSeparator("Images", Atelier.theme.font);
            sep.setColor(Atelier.theme.neutral);
            sep.setPadding(Vec2f(284f, 0f));
            sep.setSpacing(8f);
            sep.setLineWidth(1f);
            vlist.addList(sep);
        }

        {
            foreach (field; ["Colonnes", "Lignes", "Limite"]) {
                IntegerField numField = new IntegerField();
                numField.setMinValue(0);
                numField.addEventListener("value", {
                    dispatchEvent("property_misc", false);
                });
                _countFields ~= numField;

                if (field == "Limite") {
                    numField.isEnabled = hasMaxCount;

                    _hasMaxCountCB = new Checkbox(hasMaxCount);
                    _hasMaxCountCB.addEventListener("value", {
                        dispatchEvent("property_misc", false);
                        numField.isEnabled = _hasMaxCountCB.value;
                    });

                    HLayout hlayout = new HLayout;
                    hlayout.setPadding(Vec2f(284f, 0f));
                    vlist.addList(hlayout);

                    hlayout.addUI(new Label("Limiter ?", Atelier.theme.font));
                    hlayout.addUI(_hasMaxCountCB);
                }

                {
                    HLayout hlayout = new HLayout;
                    hlayout.setPadding(Vec2f(284f, 0f));
                    vlist.addList(hlayout);

                    hlayout.addUI(new Label(field ~ ":", Atelier.theme.font));
                    hlayout.addUI(numField);
                }
            }

            _countFields[0].value = columns;
            _countFields[1].value = lines;
            _countFields[2].value = maxCount;
        }

        {
            LabelSeparator sep = new LabelSeparator("Lecture", Atelier.theme.font);
            sep.setColor(Atelier.theme.neutral);
            sep.setPadding(Vec2f(284f, 0f));
            sep.setSpacing(8f);
            sep.setLineWidth(1f);
            vlist.addList(sep);
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vlist.addList(hlayout);

            {
                hlayout.addUI(new Label("Boucler ?", Atelier.theme.font));

                _repeatCB = new Checkbox(repeat);
                _repeatCB.addEventListener("value", {
                    dispatchEvent("property_misc", false);
                });
                hlayout.addUI(_repeatCB);
            }

            hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vlist.addList(hlayout);

            {
                hlayout.addUI(new Label("Délai inter-images:", Atelier.theme.font));

                _frameTimeField = new IntegerField();
                _frameTimeField.setMinValue(0);
                _frameTimeField.addEventListener("value", {
                    dispatchEvent("property_misc", false);
                });
                hlayout.addUI(_frameTimeField);

                _frameTimeField.value = frameTime;
            }
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vlist.addList(hlayout);

            hlayout.addUI(new Label("Séquence:", Atelier.theme.font));

            _framesField = new TextField();
            _framesField.setAllowedCharacters(" 0123456789");
            _framesField.addEventListener("value", {
                dispatchEvent("property_misc", false);
            });
            hlayout.addUI(_framesField);

            string value;
            foreach (i; frames) {
                value ~= to!string(i) ~ " ";
            }
            _framesField.value = value;
        }

        addEventListener("size", {
            vlist.setSize(Vec2f.zero.max(getSize() - Vec2f(8f, 8f)));
        });

        addEventListener("draw", {
            Atelier.renderer.drawRect(Vec2f.zero, getSize(), Atelier.theme.surface, 1f, true);
        });
    }

    string getTextureRID() const {
        return _textureSelect.value();
    }

    Vec4u getClip() const {
        return Vec4u(_clipFields[0].value(), _clipFields[1].value(),
            _clipFields[2].value(), _clipFields[3].value());
    }

    void setClip(Vec4u clip) {
        Atelier.ui.blockEvents = true;
        _clipFields[0].value = clip.x;
        _clipFields[1].value = clip.y;
        _clipFields[2].value = clip.z;
        _clipFields[3].value = clip.w;
        Atelier.ui.blockEvents = false;
    }

    void getMisc(ref uint columns, ref uint lines, ref bool hasMaxCount,
        ref uint maxCount, ref Vec2i margin, ref bool repeat, ref uint frameTime, ref int[] frames) {
        columns = _countFields[0].value;
        lines = _countFields[1].value;
        maxCount = _countFields[2].value;
        hasMaxCount = _hasMaxCountCB.value;
        margin = Vec2i(_marginFields[0].value, _marginFields[1].value);
        frameTime = _frameTimeField.value;

        frames.length = 0;
        int count = hasMaxCount ? maxCount : (columns * lines);
        foreach (element; _framesField.value.split(' ')) {
            try {
                uint frame = to!uint(element);
                if (frame < count) {
                    frames ~= frame;
                }
            }
            catch (ConvException e) {
            }
        }
    }
}
