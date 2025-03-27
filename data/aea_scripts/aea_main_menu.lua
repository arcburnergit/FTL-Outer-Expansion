local image = Hyperspace.Resources:CreateImagePrimitiveString("aea_main_menu_image.png", 700, 560, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

script.on_render_event(Defines.RenderEvents.MAIN_MENU, function() end, function()
    local menu = Hyperspace.Global.GetInstance():GetCApp().menu
    if menu.shipBuilder.bOpen then
        return
    end
    Graphics.CSurface.GL_RenderPrimitive(image)
end)