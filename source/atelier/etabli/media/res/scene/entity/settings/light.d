module atelier.etabli.media.res.scene.entity.settings.light;

import atelier;
import atelier.etabli.ui;
import atelier.etabli.media.res.scene.common;

package(atelier.etabli.media.res.scene) class LightSettings : UIElement {
    private {
        SceneDefinition.Light _light;
        SelectButton _graphicBtn;
        TextField _nameField;
        IntegerField _posXField, _posYField;
        HSlider _brightnessSlider;
        NumberField _brightnessField, _radiusField;
    }

    this(SceneDefinition.Light light) {
        _light = light;
        setSize(Vec2f(284f, 448f));
        setAlign(UIAlignX.left, UIAlignY.top);

        {
            LabelSeparator title = new LabelSeparator("Lumière", Atelier.theme.font);
            title.setColor(Atelier.theme.neutral);
            title.setPadding(Vec2f(284f, 0f));
            title.setSpacing(8f);
            title.setLineWidth(1f);
            title.setAlign(UIAlignX.center, UIAlignY.top);
            title.setPosition(Vec2f(0f, 8f));
            addUI(title);
        }

        VBox vbox = new VBox;
        vbox.setAlign(UIAlignX.center, UIAlignY.top);
        vbox.setPosition(Vec2f(0f, 32f));
        vbox.setSpacing(16f);
        vbox.setChildAlign(UIAlignX.center);
        addUI(vbox);

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vbox.addUI(hlayout);

            hlayout.addUI(new Label("Nom:", Atelier.theme.font));

            _nameField = new TextField;
            _nameField.value = _light.name;
            _nameField.addEventListener("value", {
                _light.name = _nameField.value;
                setDirty();
            });
            hlayout.addUI(_nameField);
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vbox.addUI(hlayout);

            hlayout.addUI(new Label("x:", Atelier.theme.font));

            _posXField = new IntegerField;
            _posXField.value = _light.position.x;
            _posXField.addEventListener("value", {
                _light.position = Vec2i(_posXField.value, _light.position.y);
                setDirty();
            });
            hlayout.addUI(_posXField);

            hlayout.addUI(new Label("y:", Atelier.theme.font));

            _posYField = new IntegerField;
            _posYField.value = _light.position.y;
            _posYField.addEventListener("value", {
                _light.position = Vec2i(_light.position.x, _posYField.value);
                setDirty();
            });
            hlayout.addUI(_posYField);
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vbox.addUI(hlayout);

            hlayout.addUI(new Label("Rayon:", Atelier.theme.font));

            _radiusField = new NumberField;
            _radiusField.setMinValue(0f);
            _radiusField.value = _light.radius;
            _radiusField.addEventListener("value", {
                _light.radius = _radiusField.value;
                setDirty();
            });
            hlayout.addUI(_radiusField);
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vbox.addUI(hlayout);

            hlayout.addUI(new Label("Couleur:", Atelier.theme.font));

            ColorButton colorBtn = new ColorButton();
            colorBtn.value = _light.color;
            colorBtn.addEventListener("value", {
                _light.color = colorBtn.value();
                setDirty();
            });
            hlayout.addUI(colorBtn);
        }

        {
            HLayout hlayout = new HLayout;
            hlayout.setPadding(Vec2f(284f, 0f));
            vbox.addUI(hlayout);

            hlayout.addUI(new Label("Lum:", Atelier.theme.font));

            _brightnessSlider = new HSlider;
            _brightnessSlider.minValue = 0f;
            _brightnessSlider.maxValue = 1f;
            _brightnessSlider.steps = 100;
            _brightnessSlider.fvalue = _light.brightness;
            _brightnessSlider.addEventListener("value", {
                _light.brightness = _brightnessSlider.fvalue;
                _brightnessField.value = _brightnessSlider.fvalue;
                setDirty();
            });
            hlayout.addUI(_brightnessSlider);

            _brightnessField = new NumberField;
            _brightnessField.setRange(0f, 1f);
            _brightnessField.setStep(.1f);
            _brightnessField.value = _light.brightness;
            _brightnessField.addEventListener("value", {
                _light.brightness = _brightnessField.value;
                _brightnessSlider.fvalue = _brightnessField.value;
                setDirty();
            });
            hlayout.addUI(_brightnessField);
        }

        {
            DangerButton btn = new DangerButton("Supprimer");
            btn.addEventListener("click", {
                dispatchEvent("light_remove", false);
            });
            vbox.addUI(btn);
        }

        addEventListener("light_update", &_updateLight);
    }

    private void _updateLight() {
        _posXField.value = _light.tempPosition.x;
        _posYField.value = _light.tempPosition.y;
        setDirty();
    }

    void setDirty() {
        dispatchEvent("property_dirty", false);
    }
}
