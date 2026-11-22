//
//  ImGuiViewController.mm
//  imgui
//
//  Standalone ImGui app: renders the interface with the Metal backend inside
//  its own window. No private APIs, no jailbreak, no overlay over other apps.
//

#import "ImGuiViewController.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

#import "imgui.h"
#import "imgui_internal.h"
#import "backends/imgui_impl_metal.h"

@interface ImGuiMTKView : MTKView

@property (nonatomic, copy) void (^touchHandler)(NSSet<UITouch *> *touches, BOOL ended);

@end

@implementation ImGuiMTKView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.touchHandler) {
        self.touchHandler(touches, NO);
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.touchHandler) {
        self.touchHandler(touches, NO);
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.touchHandler) {
        self.touchHandler(touches, YES);
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.touchHandler) {
        self.touchHandler(touches, YES);
    }
}

@end

#pragma mark -

@interface ImGuiViewController () <MTKViewDelegate>
@end

@implementation ImGuiViewController {
    ImGuiMTKView *_mtkView;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;

    BOOL _imguiReady;
    BOOL _espEnabled;
    CFTimeInterval _lastFrameTime;

    UITouch *__weak _activeTouch;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.12 alpha:1.0];

    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        [self showMetalUnavailable];
        return;
    }

    _commandQueue = [_device newCommandQueue];

    _mtkView = [[ImGuiMTKView alloc] initWithFrame:self.view.bounds device:_device];
    _mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mtkView.delegate = self;
    _mtkView.clearColor = MTLClearColorMake(0.08, 0.11, 0.12, 1.0);
    _mtkView.preferredFramesPerSecond = 60;
    _mtkView.multipleTouchEnabled = NO;

    __weak ImGuiViewController *weakSelf = self;
    _mtkView.touchHandler = ^(NSSet<UITouch *> *touches, BOOL ended) {
        [weakSelf handleTouches:touches ended:ended];
    };
    [self.view addSubview:_mtkView];

    [self setupImGui];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _mtkView.frame = self.view.bounds;
}

- (void)showMetalUnavailable
{
    UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.text = @"Metal is not available on this device.";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
}

- (void)dealloc
{
    _mtkView.delegate = nil;
    if (_imguiReady) {
        ImGui_ImplMetal_Shutdown();
        ImGui::DestroyContext();
    }
}

#pragma mark - ImGui setup

- (void)setupImGui
{
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = NULL;
    io.LogFilename = NULL;
    io.ConfigFlags |= ImGuiConfigFlags_IsTouchScreen;
    io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;

    ImGui::StyleColorsDark();
    ImGui::GetStyle().TouchExtraPadding = ImVec2(8.0f, 8.0f);

    io.Fonts->AddFontDefault();

    ImGui_ImplMetal_Init(_device);
    _imguiReady = YES;
    _lastFrameTime = CACurrentMediaTime();
}

#pragma mark - Touch input

- (void)handleTouches:(NSSet<UITouch *> *)touches ended:(BOOL)ended
{
    if (!_imguiReady) {
        return;
    }

    UITouch *touch = nil;
    if (_activeTouch && [touches containsObject:_activeTouch]) {
        touch = _activeTouch;
    } else if (!ended) {
        touch = touches.anyObject;
        _activeTouch = touch;
    }

    if (!touch) {
        return;
    }

    const CGPoint point = [touch locationInView:_mtkView];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMousePosEvent((float)point.x, (float)point.y);
    io.AddMouseButtonEvent(0, !ended);

    if (ended) {
        _activeTouch = nil;
    }
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    (void)view;
    (void)size;
}

- (void)drawInMTKView:(MTKView *)view
{
    if (!_imguiReady) {
        return;
    }

    MTLRenderPassDescriptor *renderPass = view.currentRenderPassDescriptor;
    if (!renderPass) {
        return;
    }

    ImGuiIO &io = ImGui::GetIO();

    const CGSize boundsSize = view.bounds.size;
    io.DisplaySize = ImVec2((float)boundsSize.width, (float)boundsSize.height);

    CGFloat framebufferScale = view.contentScaleFactor;
    if (framebufferScale <= 0.0) {
        framebufferScale = [UIScreen mainScreen].nativeScale;
    }
    io.DisplayFramebufferScale = ImVec2((float)framebufferScale, (float)framebufferScale);

    const CFTimeInterval now = CACurrentMediaTime();
    float delta = (float)(now - _lastFrameTime);
    _lastFrameTime = now;
    if (delta <= 0.0f || delta > 0.25f) {
        delta = 1.0f / 60.0f;
    }
    io.DeltaTime = delta;

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPass];

    ImGui_ImplMetal_NewFrame(renderPass);
    ImGui::NewFrame();

    [self drawInterface];

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);

    [renderEncoder endEncoding];

    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (drawable) {
        [commandBuffer presentDrawable:drawable];
    }
    [commandBuffer commit];
}

#pragma mark - Interface

- (void)drawInterface
{
    ImGuiIO &io = ImGui::GetIO();

    const float windowWidth = ImMin(360.0f, io.DisplaySize.x - 24.0f);
    ImGui::SetNextWindowPos(ImVec2((io.DisplaySize.x - windowWidth) * 0.5f, 24.0f),
                            ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(windowWidth, 0.0f), ImGuiCond_FirstUseEver);

    ImGui::Begin("Droid Client | IOS", nullptr, ImGuiWindowFlags_NoCollapse);

    ImGui::Checkbox("ESP (demo)", &_espEnabled);
    ImGui::Text("display size: %.0f x %.0f", io.DisplaySize.x, io.DisplaySize.y);
    ImGui::Text("fb scale:     %.1f", io.DisplayFramebufferScale.x);
    ImGui::Text("fps:          %.1f", io.Framerate);
    ImGui::Separator();
    ImGui::TextWrapped("Standalone ImGui app. No jailbreak required.");

    [self keepWindowOnScreen];

    ImGui::End();

    if (_espEnabled) {
        [self drawDemoShapes];
    }
}

- (void)keepWindowOnScreen
{
    ImGuiIO &io = ImGui::GetIO();

    const ImVec2 position = ImGui::GetWindowPos();
    const ImVec2 size = ImGui::GetWindowSize();
    const ImVec2 clamped(ImClamp(position.x, 0.0f, ImMax(0.0f, io.DisplaySize.x - size.x)),
                         ImClamp(position.y, 0.0f, ImMax(0.0f, io.DisplaySize.y - size.y)));

    if (clamped.x != position.x || clamped.y != position.y) {
        ImGui::SetWindowPos(clamped);
    }
}

- (void)drawDemoShapes
{
    ImGuiIO &io = ImGui::GetIO();
    ImDrawList *drawList = ImGui::GetBackgroundDrawList();

    const float width = io.DisplaySize.x;
    const float height = io.DisplaySize.y;
    const ImU32 strokeColor = IM_COL32(255, 255, 255, 200);
    const ImU32 lineColor = IM_COL32(255, 255, 255, 90);

    const ImVec2 origin(width * 0.5f, 0.0f);
    const float heightScale[3] = {1.0f, 0.78f, 0.9f};
    const float verticalOffset[3] = {0.0f, 0.06f, -0.04f};
    const float fillLevel[3] = {0.85f, 0.45f, 0.2f};
    const char *names[3] = {"Player", "Player", "Player"};
    const char *distances[3] = {"10m", "5m", "7m"};

    ImFont *font = ImGui::GetFont();
    const float labelSize = 15.0f;
    const ImU32 shadowColor = IM_COL32(0, 0, 0, 200);
    const ImU32 nameColor = IM_COL32(255, 255, 255, 240);
    const ImU32 distanceColor = IM_COL32(220, 220, 220, 230);

    for (int i = 0; i < 3; i++) {
        const float centreX = (width / 4.0f) * (float)(i + 1);
        const float centreY = height * (0.58f + verticalOffset[i]);
        const float boxWidth = 46.0f * heightScale[i];
        const float boxHeight = 86.0f * heightScale[i];

        const ImVec2 topLeft(centreX - boxWidth * 0.5f, centreY - boxHeight * 0.5f);
        const ImVec2 bottomRight(centreX + boxWidth * 0.5f, centreY + boxHeight * 0.5f);

        drawList->AddRect(topLeft, bottomRight, strokeColor, 0.0f, 0, 1.0f);
        drawList->AddLine(origin, ImVec2(centreX, topLeft.y), lineColor, 1.0f);

        const float barWidth = 3.0f;
        const float barGap = 3.0f;
        const ImVec2 barMin(topLeft.x - barGap - barWidth, topLeft.y);
        const ImVec2 barMax(topLeft.x - barGap, bottomRight.y);

        drawList->AddRectFilled(barMin, barMax, IM_COL32(0, 0, 0, 140));

        const float fill = ImClamp(fillLevel[i], 0.0f, 1.0f);
        if (fill > 0.0f) {
            const float filledTop = barMax.y - (barMax.y - barMin.y) * fill;
            const ImU32 bottomColor = IM_COL32(220, 40, 40, 235);
            const ImU32 topColor = IM_COL32((int)(220.0f + (40.0f - 220.0f) * fill),
                                            (int)(40.0f + (220.0f - 40.0f) * fill),
                                            40,
                                            235);
            drawList->AddRectFilledMultiColor(ImVec2(barMin.x, filledTop), barMax,
                                              topColor, topColor, bottomColor, bottomColor);
        }

        drawList->AddRect(barMin, barMax, IM_COL32(0, 0, 0, 200), 0.0f, 0, 1.0f);

        const ImVec2 nameTextSize = font->CalcTextSizeA(labelSize, 1000.0f, 0.0f, names[i]);
        const ImVec2 namePos(centreX - nameTextSize.x * 0.5f, topLeft.y - nameTextSize.y - 6.0f);
        drawList->AddText(font, labelSize, ImVec2(namePos.x + 1.0f, namePos.y + 1.0f), shadowColor, names[i]);
        drawList->AddText(font, labelSize, namePos, nameColor, names[i]);

        const ImVec2 distanceTextSize = font->CalcTextSizeA(labelSize, 1000.0f, 0.0f, distances[i]);
        const ImVec2 distancePos(centreX - distanceTextSize.x * 0.5f, bottomRight.y + 6.0f);
        drawList->AddText(font, labelSize, ImVec2(distancePos.x + 1.0f, distancePos.y + 1.0f), shadowColor, distances[i]);
        drawList->AddText(font, labelSize, distancePos, distanceColor, distances[i]);
    }
}

@end
