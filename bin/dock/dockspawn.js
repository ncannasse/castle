(function()
{
    dockspawn = {version: "0.0.2"};

/**
 * A tab handle represents the tab button on the tab strip
 */
dockspawn.TabHandle = function(parent)
{
    this.parent = parent;
    var undockHandler = dockspawn.TabHandle.prototype._performUndock.bind(this);
    this.elementBase = document.createElement('div');
    this.elementText = document.createElement('div');
    this.elementCloseButton = document.createElement('div');
    this.elementBase.classList.add("tab-handle");
    this.elementBase.classList.add("disable-selection"); // Disable text selection
    this.elementText.classList.add("tab-handle-text");
    this.elementCloseButton.classList.add("tab-handle-close-button");
    this.elementBase.appendChild(this.elementText);
    if (this.parent.host.displayCloseButton)
        this.elementBase.appendChild(this.elementCloseButton);

    this.parent.host.tabListElement.appendChild(this.elementBase);

    var panel = parent.container;
    var title = panel.getRawTitle();
    this.elementText.innerHTML = title;

    // Set the close button text (font awesome)
    var closeIcon = "fa fa-remove";
    this.elementCloseButton.innerHTML = '<i class="' + closeIcon + '"></i>';

    this._bringToFront(this.elementBase);

    this.undockInitiator = new dockspawn.UndockInitiator(this.elementBase, undockHandler);
    this.undockInitiator.enabled = true;

    this.mouseClickHandler = new dockspawn.EventHandler(this.elementBase, 'click', this.onMouseClicked.bind(this));                     // Button click handler for the tab handle
    this.closeButtonHandler = new dockspawn.EventHandler(this.elementCloseButton, 'mousedown', this.onCloseButtonClicked.bind(this));   // Button click handler for the close button

    this.zIndexCounter = 1000;
};

dockspawn.TabHandle.prototype.updateTitle = function()
{
    if (this.parent.container instanceof dockspawn.PanelContainer)
    {
        var panel = this.parent.container;
        var title = panel.getRawTitle();
        this.elementText.innerHTML = title;
    }
};

dockspawn.TabHandle.prototype.destroy = function()
{
    this.mouseClickHandler.cancel();
    this.closeButtonHandler.cancel();
    removeNode(this.elementBase);
    removeNode(this.elementCloseButton);
    delete this.elementBase;
    delete this.elementCloseButton;
};

dockspawn.TabHandle.prototype._performUndock = function(e, dragOffset)
{
    if (this.parent.container.containerType == "panel")
    {
        this.undockInitiator.enabled = false;
        var panel = this.parent.container;
        return panel.performUndockToDialog(e, dragOffset);
    }
    else
        return null;
};

dockspawn.TabHandle.prototype.onMouseClicked = function()
{
    this.parent.onSelected();
};

dockspawn.TabHandle.prototype.onCloseButtonClicked = function()
{
    // If the page contains a panel element, undock it and destroy it
    if (this.parent.container.containerType == "panel")
    {
        this.undockInitiator.enabled = false;
        var panel = this.parent.container;
        panel.performUndock();
		panel.destroy();
    }
};

dockspawn.TabHandle.prototype.setSelected = function(selected)
{
    var selectedClassName = "tab-handle-selected";
    if (selected)
        this.elementBase.classList.add(selectedClassName);
    else
        this.elementBase.classList.remove(selectedClassName);
};

dockspawn.TabHandle.prototype.setZIndex = function(zIndex)
{
    this.elementBase.style.zIndex = zIndex;
};

dockspawn.TabHandle.prototype._bringToFront = function(element)
{
    element.style.zIndex = this.zIndexCounter;
    this.zIndexCounter++;
};
/**
 * Tab Host control contains tabs known as TabPages.
 * The tab strip can be aligned in different orientations
 */
dockspawn.TabHost = function(tabStripDirection, displayCloseButton)
{
    /**
     * Create a tab host with the tab strip aligned in the [tabStripDirection] direciton
     * Only dockspawn.TabHost.DIRECTION_BOTTOM and dockspawn.TabHost.DIRECTION_TOP are supported
     */
    if (tabStripDirection === undefined)
        tabStripDirection = dockspawn.TabHost.DIRECTION_BOTTOM;
    if (displayCloseButton === undefined)
        displayCloseButton = false;

    this.tabStripDirection = tabStripDirection;
    this.displayCloseButton = displayCloseButton;           // Indicates if the close button next to the tab handle should be displayed
    this.pages = [];
    this.hostElement = document.createElement('div');       // The main tab host DOM element
    this.tabListElement = document.createElement('div');    // Hosts the tab handles
    this.separatorElement = document.createElement('div');  // A seperator line between the tabs and content
    this.contentElement = document.createElement('div');    // Hosts the active tab content
    this.createTabPage = this._createDefaultTabPage;        // Factory for creating tab pages

    if (this.tabStripDirection == dockspawn.TabHost.DIRECTION_BOTTOM)
    {
        this.hostElement.appendChild(this.contentElement);
        this.hostElement.appendChild(this.separatorElement);
        this.hostElement.appendChild(this.tabListElement);
    }
    else if (this.tabStripDirection == dockspawn.TabHost.DIRECTION_TOP)
    {
        this.hostElement.appendChild(this.tabListElement);
        this.hostElement.appendChild(this.separatorElement);
        this.hostElement.appendChild(this.contentElement);
    }
    else
        throw new dockspawn.Exception("Only top and bottom tab strip orientations are supported");

    this.hostElement.classList.add("tab-host");
    this.tabListElement.classList.add("tab-handle-list-container");
    this.separatorElement.classList.add("tab-handle-content-seperator");
    this.contentElement.classList.add("tab-content");
};

// constants
dockspawn.TabHost.DIRECTION_TOP = 0;
dockspawn.TabHost.DIRECTION_BOTTOM = 1;
dockspawn.TabHost.DIRECTION_LEFT = 2;
dockspawn.TabHost.DIRECTION_RIGHT = 3;

dockspawn.TabHost.prototype._createDefaultTabPage = function(tabHost, container)
{
    return new dockspawn.TabPage(tabHost, container);
};

dockspawn.TabHost.prototype.setActiveTab = function(container)
{
    var self = this;
    this.pages.forEach(function(page)
    {
        if (page.container === container)
        {
            self.onTabPageSelected(page);
            return;
        }
    });
};

dockspawn.TabHost.prototype.resize = function(width, height)
{
    this.hostElement.style.width = width + "px";
    this.hostElement.style.height = height + "px";

    var tabHeight = this.tabListElement.clientHeight;
    var separatorHeight = this.separatorElement.clientHeight;
    var contentHeight = height - tabHeight - separatorHeight;
    this.contentElement.style.height = contentHeight + "px";

    if (this.activeTab)
        this.activeTab.resize(width, contentHeight);
};

dockspawn.TabHost.prototype.performLayout = function(children)
{
    // Destroy all existing tab pages
    this.pages.forEach(function(tab)
    {
        tab.destroy();
    });
    this.pages.length = 0;

    var oldActiveTab = this.activeTab;
    delete this.activeTab;

    var childPanels = children.filter(function(child)
    {
        return child.containerType == "panel";
    });

    if (childPanels.length > 0)
    {
        // Rebuild new tab pages
        var self = this;
        childPanels.forEach(function(child)
        {
            var page = self.createTabPage(self, child);
            self.pages.push(page);

            // Restore the active selected tab
            if (oldActiveTab && page.container === oldActiveTab.container)
                self.activeTab = page;
        });
        this._setTabHandlesVisible(true);
    }
    else
        // Do not show an empty tab handle host with zero tabs
        this._setTabHandlesVisible(false);

    if (this.activeTab)
        this.onTabPageSelected(this.activeTab);
};

dockspawn.TabHost.prototype._setTabHandlesVisible = function(visible)
{
    this.tabListElement.style.display = visible ? "block" : "none";
    this.separatorElement.style.display = visible ? "block" : "none";
};

dockspawn.TabHost.prototype.onTabPageSelected = function(page)
{
    this.activeTab = page;
    this.pages.forEach(function(tabPage)
    {
        var selected = (tabPage === page);
        tabPage.setSelected(selected);
    });

    // adjust the zIndex of the tabs to have proper shadow/depth effect
    var zIndexDelta = 1;
    var zIndex = 1000;
    this.pages.forEach(function(tabPage)
    {
        tabPage.handle.setZIndex(zIndex);
        var selected = (tabPage == page);
        if (selected)
            zIndexDelta = -1;
        zIndex += zIndexDelta;
    });

    // If a callback is defined, then notify it of this event
    //if (this.onTabChanged)
    //    this.onTabChanged(this, page);
};

dockspawn.TabPage = function(host, container)
{
    if (arguments.length == 0)
        return;

    this.selected = false;
    this.host = host;
    this.container = container;

    this.handle = new dockspawn.TabHandle(this);
    this.containerElement = container.containerElement;

    if (container instanceof dockspawn.PanelContainer)
    {
        var panel = container;
        panel.onTitleChanged = this.onTitleChanged.bind(this);
    }
};

dockspawn.TabPage.prototype.onTitleChanged = function(sender, title)
{
    this.handle.updateTitle();
};

dockspawn.TabPage.prototype.destroy = function()
{
    this.handle.destroy();

    if (this.container instanceof dockspawn.PanelContainer)
    {
        var panel = this.container;
        delete panel.onTitleChanged;
    }
};

dockspawn.TabPage.prototype.onSelected = function()
{
    this.host.onTabPageSelected(this);
};

dockspawn.TabPage.prototype.setSelected = function(flag)
{
    this.selected = flag;
    this.handle.setSelected(flag);

    if (this.selected)
    {
        this.host.contentElement.appendChild(this.containerElement);
        // force a resize again
        var width = this.host.contentElement.clientWidth;
        var height = this.host.contentElement.clientHeight;
        this.container.resize(width, height);
    }
    else
        removeNode(this.containerElement);
};

dockspawn.TabPage.prototype.resize = function(width, height)
{
    this.container.resize(width, height);
};
dockspawn.Dialog = function(panel, dockManager)
{
    this.panel = panel;
    this.zIndexCounter = 1000;
    this.dockManager = dockManager;
    this.eventListener = dockManager;
    this._initialize();
};

dockspawn.Dialog.fromElement = function(id, dockManager)
{
    return new dockspawn.Dialog(new dockspawn.PanelContainer(document.getElementById(id), dockManager), dockManager);
};

dockspawn.Dialog.prototype._initialize = function()
{
    this.panel.floatingDialog = this;
    this.elementDialog = document.createElement('div');
    this.elementDialog.appendChild(this.panel.elementPanel);
    this.draggable = new dockspawn.DraggableContainer(this, this.panel, this.elementDialog, this.panel.elementTitle);
    this.resizable = new dockspawn.ResizableContainer(this, this.draggable, this.draggable.topLevelElement);

    document.body.appendChild(this.elementDialog);
    this.elementDialog.classList.add("dialog-floating");
    this.elementDialog.classList.add("rounded-corner-top");
    this.panel.elementTitle.classList.add("rounded-corner-top");

    this.mouseDownHandler = new dockspawn.EventHandler(this.elementDialog, 'mousedown', this.onMouseDown.bind(this));
    this.resize(this.panel.elementPanel.clientWidth, this.panel.elementPanel.clientHeight);
    this.bringToFront();
};

dockspawn.Dialog.prototype.setPosition = function(x, y)
{
    this.elementDialog.style.left = x + "px";
    this.elementDialog.style.top = y + "px";
};

dockspawn.Dialog.prototype.onMouseDown = function(e)
{
    this.bringToFront();
};

dockspawn.Dialog.prototype.destroy = function()
{
    if (this.mouseDownHandler)
    {
        this.mouseDownHandler.cancel();
        delete this.mouseDownHandler;
    }
    this.elementDialog.classList.remove("rounded-corner-top");
    this.panel.elementTitle.classList.remove("rounded-corner-top");
    removeNode(this.elementDialog);
    this.draggable.removeDecorator();
    removeNode(this.panel.elementPanel);
    delete this.panel._floatingDialog;
};

dockspawn.Dialog.prototype.resize = function(width, height)
{
    this.resizable.resize(width, height);
};

dockspawn.Dialog.prototype.setTitle = function(title)
{
    this.panel.setTitle(title);
};

dockspawn.Dialog.prototype.setTitleIcon = function(iconName)
{
    this.panel.setTitleIcon(iconName);
};

dockspawn.Dialog.prototype.bringToFront = function()
{
    this.elementDialog.style.zIndex = this.zIndexCounter++;
};
dockspawn.DraggableContainer = function(dialog, delegate, topLevelElement, dragHandle)
{
    this.dialog = dialog;
    this.delegate = delegate;
    this.containerElement = delegate.containerElement;
    this.dockManager = delegate.dockManager;
    this.topLevelElement = topLevelElement;
    this.containerType = delegate.containerType;
    this.mouseDownHandler = new dockspawn.EventHandler(dragHandle, 'mousedown', this.onMouseDown.bind(this));
    this.topLevelElement.style.marginLeft = topLevelElement.offsetLeft + "px";
    this.topLevelElement.style.marginTop = topLevelElement.offsetTop + "px";
    this.minimumAllowedChildNodes = delegate.minimumAllowedChildNodes;
};

dockspawn.DraggableContainer.prototype.destroy = function()
{
    this.removeDecorator();
    this.delegate.destroy();
};

dockspawn.DraggableContainer.prototype.saveState = function(state)
{
    this.delegate.saveState(state);
};

dockspawn.DraggableContainer.prototype.loadState = function(state)
{
    this.delegate.loadState(state);
};

dockspawn.DraggableContainer.prototype.setActiveChild = function(child)
{
};

Object.defineProperty(dockspawn.DraggableContainer.prototype, "width", {
    get: function() { return this.delegate.width; }
});

Object.defineProperty(dockspawn.DraggableContainer.prototype, "height", {
    get: function() { return this.delegate.height; }
});

dockspawn.DraggableContainer.prototype.name = function(value)
{
    if (value)
        this.delegate.name = value;
    return this.delegate.name;
};

dockspawn.DraggableContainer.prototype.resize = function(width, height)
{
    this.delegate.resize(width, height);
};

dockspawn.DraggableContainer.prototype.performLayout = function(children)
{
    this.delegate.performLayout(children);
};

dockspawn.DraggableContainer.prototype.removeDecorator = function()
{
    if (this.mouseDownHandler)
    {
        this.mouseDownHandler.cancel();
        delete this.mouseDownHandler;
    }
};

dockspawn.DraggableContainer.prototype.onMouseDown = function(event)
{
    this._startDragging(event);
    this.previousMousePosition = { x: event.pageX, y: event.pageY };
    if (this.mouseMoveHandler)
    {
        this.mouseMoveHandler.cancel();
        delete this.mouseMoveHandler;
    }
    if (this.mouseUpHandler)
    {
        this.mouseUpHandler.cancel();
        delete this.mouseUpHandler;
    }

    this.mouseMoveHandler = new dockspawn.EventHandler(window, 'mousemove', this.onMouseMove.bind(this));
    this.mouseUpHandler = new dockspawn.EventHandler(window, 'mouseup', this.onMouseUp.bind(this));
};

dockspawn.DraggableContainer.prototype.onMouseUp = function(event)
{
    this._stopDragging(event);
    this.mouseMoveHandler.cancel();
    delete this.mouseMoveHandler;
    this.mouseUpHandler.cancel();
    delete this.mouseUpHandler;
};

dockspawn.DraggableContainer.prototype._startDragging = function(event)
{
    if (this.dialog.eventListener)
        this.dialog.eventListener.onDialogDragStarted(this.dialog, event);
    document.body.classList.add("disable-selection");
};

dockspawn.DraggableContainer.prototype._stopDragging = function(event)
{
    if (this.dialog.eventListener)
        this.dialog.eventListener.onDialogDragEnded(this.dialog, event);
    document.body.classList.remove("disable-selection");
};

dockspawn.DraggableContainer.prototype.onMouseMove = function(event)
{
    var currentMousePosition = new Point(event.pageX, event.pageY);
    var dx = Math.floor(currentMousePosition.x - this.previousMousePosition.x);
    var dy = Math.floor(currentMousePosition.y - this.previousMousePosition.y);
    this._performDrag(dx, dy);
    this.previousMousePosition = currentMousePosition;
};

dockspawn.DraggableContainer.prototype._performDrag = function(dx, dy)
{
    var left = dx + getPixels(this.topLevelElement.style.marginLeft);
    var top = dy + getPixels(this.topLevelElement.style.marginTop);
    this.topLevelElement.style.marginLeft = left + "px";
    this.topLevelElement.style.marginTop = top + "px";
};
/**
 * Decorates a dock container with resizer handles around its base element
 * This enables the container to be resized from all directions
 */
dockspawn.ResizableContainer = function(dialog, delegate, topLevelElement)
{
    this.dialog = dialog;
    this.delegate = delegate;
    this.containerElement = delegate.containerElement;
    this.dockManager = delegate.dockManager;
    this.topLevelElement = topLevelElement;
    this.containerType = delegate.containerType;
    this.topLevelElement.style.marginLeft = this.topLevelElement.offsetLeft + "px";
    this.topLevelElement.style.marginTop = this.topLevelElement.offsetTop + "px";
    this.minimumAllowedChildNodes = delegate.minimumAllowedChildNodes;
    this._buildResizeHandles();
    this.readyToProcessNextResize = true;
};

dockspawn.ResizableContainer.prototype.setActiveChild = function(child)
{
};

dockspawn.ResizableContainer.prototype._buildResizeHandles = function()
{
    this.resizeHandles = [];
//    this._buildResizeHandle(true, false, true, false); // Dont need the corner resizer near the close button
    this._buildResizeHandle(false, true, true, false);
    this._buildResizeHandle(true, false, false, true);
    this._buildResizeHandle(false, true, false, true);

    this._buildResizeHandle(true, false, false, false);
    this._buildResizeHandle(false, true, false, false);
    this._buildResizeHandle(false, false, true, false);
    this._buildResizeHandle(false, false, false, true);
};

dockspawn.ResizableContainer.prototype._buildResizeHandle = function(east, west, north, south)
{
    var handle = new ResizeHandle();
    handle.east = east;
    handle.west = west;
    handle.north = north;
    handle.south = south;

    // Create an invisible div for the handle
    handle.element = document.createElement('div');
    this.topLevelElement.appendChild(handle.element);

    // Build the class name for the handle
    var verticalClass = "";
    var horizontalClass = "";
    if (north) verticalClass = "n";
    if (south) verticalClass = "s";
    if (east) horizontalClass = "e";
    if (west) horizontalClass = "w";
    var cssClass = "resize-handle-" + verticalClass + horizontalClass;
    if (verticalClass.length > 0 && horizontalClass.length > 0)
        handle.corner = true;

    handle.element.classList.add(handle.corner ? "resize-handle-corner" : "resize-handle");
    handle.element.classList.add(cssClass);
    this.resizeHandles.push(handle);

    var self = this;
    handle.mouseDownHandler = new dockspawn.EventHandler(handle.element, 'mousedown', function(e) { self.onMouseDown(handle, e); });
};

dockspawn.ResizableContainer.prototype.saveState = function(state)
{
    this.delegate.saveState(state);
};

dockspawn.ResizableContainer.prototype.loadState = function(state)
{
    this.delegate.loadState(state);
};

Object.defineProperty(dockspawn.ResizableContainer.prototype, "width", {
    get: function() { return this.delegate.width; }
});

Object.defineProperty(dockspawn.ResizableContainer.prototype, "height", {
    get: function() { return this.delegate.height; }
});

dockspawn.ResizableContainer.prototype.name = function(value)
{
    if (value)
        this.delegate.name = value;
    return this.delegate.name;
};

dockspawn.ResizableContainer.prototype.resize = function(width, height)
{
    this.delegate.resize(width, height);
    this._adjustResizeHandles(width, height);
};

dockspawn.ResizableContainer.prototype._adjustResizeHandles = function(width, height)
{
    var self = this;
    this.resizeHandles.forEach(function(handle) {
        handle.adjustSize(self.topLevelElement, width, height);
    });
};

dockspawn.ResizableContainer.prototype.performLayout = function(children)
{
    this.delegate.performLayout(children);
};

dockspawn.ResizableContainer.prototype.destroy = function()
{
    this.removeDecorator();
    this.delegate.destroy();
};

dockspawn.ResizableContainer.prototype.removeDecorator = function()
{
};

dockspawn.ResizableContainer.prototype.onMouseMoved = function(handle, e)
{
    if (!this.readyToProcessNextResize)
        return;
    this.readyToProcessNextResize = false;

//    window.requestLayoutFrame(() {
    this.dockManager.suspendLayout();
    var currentMousePosition = new Point(e.pageX, e.pageY);
    var dx = Math.floor(currentMousePosition.x - this.previousMousePosition.x);
    var dy = Math.floor(currentMousePosition.y - this.previousMousePosition.y);
    this._performDrag(handle, dx, dy);
    this.previousMousePosition = currentMousePosition;
    this.readyToProcessNextResize = true;
    this.dockManager.resumeLayout();
//    });
};

dockspawn.ResizableContainer.prototype.onMouseDown = function(handle, event)
{
    this.previousMousePosition = new Point(event.pageX, event.pageY);
    if (handle.mouseMoveHandler)
    {
        handle.mouseMoveHandler.cancel();
        delete handle.mouseMoveHandler
    }
    if (handle.mouseUpHandler)
    {
        handle.mouseUpHandler.cancel();
        delete handle.mouseUpHandler
    }

    // Create the mouse event handlers
    var self = this;
    handle.mouseMoveHandler = new dockspawn.EventHandler(window, 'mousemove', function(e) { self.onMouseMoved(handle, e); });
    handle.mouseUpHandler = new dockspawn.EventHandler(window, 'mouseup', function(e) { self.onMouseUp(handle, e); });

    document.body.classList.add("disable-selection");
};

dockspawn.ResizableContainer.prototype.onMouseUp = function(handle, event)
{
    handle.mouseMoveHandler.cancel();
    handle.mouseUpHandler.cancel();
    delete handle.mouseMoveHandler;
    delete handle.mouseUpHandler;

    document.body.classList.remove("disable-selection");
};

dockspawn.ResizableContainer.prototype._performDrag = function(handle, dx, dy)
{
    var bounds = {};
    bounds.left = getPixels(this.topLevelElement.style.marginLeft);
    bounds.top = getPixels(this.topLevelElement.style.marginTop);
    bounds.width = this.topLevelElement.clientWidth;
    bounds.height = this.topLevelElement.clientHeight;

    if (handle.east) this._resizeEast(dx, bounds);
    if (handle.west) this._resizeWest(dx, bounds);
    if (handle.north) this._resizeNorth(dy, bounds);
    if (handle.south) this._resizeSouth(dy, bounds);
};

dockspawn.ResizableContainer.prototype._resizeWest = function(dx, bounds)
{
    this._resizeContainer(dx, 0, -dx, 0, bounds);
};

dockspawn.ResizableContainer.prototype._resizeEast = function(dx, bounds)
{
    this._resizeContainer(0, 0, dx, 0, bounds);
};

dockspawn.ResizableContainer.prototype._resizeNorth = function(dy, bounds)
{
    this._resizeContainer(0, dy, 0, -dy, bounds);
};

dockspawn.ResizableContainer.prototype._resizeSouth = function(dy, bounds)
{
    this._resizeContainer(0, 0, 0, dy, bounds);
};

dockspawn.ResizableContainer.prototype._resizeContainer = function(leftDelta, topDelta, widthDelta, heightDelta, bounds)
{
    bounds.left += leftDelta;
    bounds.top += topDelta;
    bounds.width += widthDelta;
    bounds.height += heightDelta;

    var minWidth = 50;  // TODO: Move to external configuration
    var minHeight = 50;  // TODO: Move to external configuration
    bounds.width = Math.max(bounds.width, minWidth);
    bounds.height = Math.max(bounds.height, minHeight);

    this.topLevelElement.style.marginLeft = bounds.left + "px";
    this.topLevelElement.style.marginTop = bounds.top + "px";

    this.resize(bounds.width, bounds.height);
};


function ResizeHandle()
{
    this.element = undefined;
    this.handleSize = 6;   // TODO: Get this from DOM
    this.cornerSize = 12;  // TODO: Get this from DOM
    this.east = false;
    this.west = false;
    this.north = false;
    this.south = false;
    this.corner = false;
}

ResizeHandle.prototype.adjustSize = function(container, clientWidth, clientHeight)
{
    if (this.corner)
    {
        if (this.west) this.element.style.left = "0px";
        if (this.east) this.element.style.left = (clientWidth - this.cornerSize) + "px";
        if (this.north) this.element.style.top = "0px";
        if (this.south) this.element.style.top = (clientHeight - this.cornerSize) + "px";
    }
    else
    {
        if (this.west)
        {
            this.element.style.left = "0px";
            this.element.style.top = this.cornerSize + "px";
        }
        if (this.east) {
            this.element.style.left = (clientWidth - this.handleSize) + "px";
            this.element.style.top = this.cornerSize + "px";
        }
        if (this.north) {
            this.element.style.left = this.cornerSize + "px";
            this.element.style.top = "0px";
        }
        if (this.south) {
            this.element.style.left = this.cornerSize + "px";
            this.element.style.top = (clientHeight - this.handleSize) + "px";
        }

        if (this.west || this.east) {
            this.element.style.height = (clientHeight - this.cornerSize * 2) + "px";
        } else {
            this.element.style.width = (clientWidth - this.cornerSize * 2) + "px";
        }
    }
};
dockspawn.Exception = function(message)
{
    this.message = message;
}

dockspawn.Exception.prototype.toString = function()
{
    return this.message;
};
/**
 * Dock manager manages all the dock panels in a hierarchy, similar to visual studio.
 * It owns a Html Div element inside which all panels are docked
 * Initially the document manager takes up the central space and acts as the root node
 */

 dockspawn.DockManager = function(element)
{
    if (element === undefined)
        throw new dockspawn.Exception("Invalid Dock Manager element provided");

    this.element = element;
    this.context = this.dockWheel = this.layoutEngine = this.mouseMoveHandler = undefined;
    this.layoutEventListeners = [];
};

dockspawn.DockManager.prototype.initialize = function()
{
    this.context = new dockspawn.DockManagerContext(this);
    var documentNode = new dockspawn.DockNode(this.context.documentManagerView);
    this.context.model.rootNode = documentNode;
    this.context.model.documentManagerNode = documentNode;
    this.setRootNode(this.context.model.rootNode);
    // Resize the layout
	this.resize(this.element.clientWidth, this.element.clientHeight);
    this.dockWheel = new dockspawn.DockWheel(this);
    this.layoutEngine = new dockspawn.DockLayoutEngine(this);

    this.rebuildLayout(this.context.model.rootNode);
};

dockspawn.DockManager.prototype.rebuildLayout = function(node)
{
    var self = this;
    node.children.forEach(function(child) { self.rebuildLayout(child); });
    node.performLayout();
};

dockspawn.DockManager.prototype.invalidate = function()
{
    this.resize(this.element.clientWidth, this.element.clientHeight);
};

dockspawn.DockManager.prototype.resize = function(width, height)
{
	if( width <= 0 ) width = parseInt(this.element.style.width);
	if( height <= 0 ) height = parseInt(this.element.style.height);
    this.element.style.width = width + "px";
    this.element.style.height = height + "px";
    this.context.model.rootNode.container.resize(width, height);
};

/**
 * Reset the dock model . This happens when the state is loaded from json
 */
dockspawn.DockManager.prototype.setModel = function(model)
{
    removeNode(this.context.documentManagerView.containerElement);
    this.context.model = model;
    this.setRootNode(model.rootNode);

    this.rebuildLayout(model.rootNode);
    this.invalidate();
};

dockspawn.DockManager.prototype.setRootNode = function(node)
{
    if (this.context.model.rootNode)
    {
        // detach it from the dock manager's base element
//      context.model.rootNode.detachFromParent();
    }

    // Attach the new node to the dock manager's base element and set as root node
    node.detachFromParent();
    this.context.model.rootNode = node;
    this.element.appendChild(node.container.containerElement);
};


dockspawn.DockManager.prototype.onDialogDragStarted = function(sender, e)
{
    this.dockWheel.activeNode = this._findNodeOnPoint(e.pageX, e.pageY);
    this.dockWheel.activeDialog = sender;
    this.dockWheel.showWheel();
    if (this.mouseMoveHandler)
    {
        this.mouseMoveHandler.cancel();
        delete this.mouseMoveHandler;
    }
    this.mouseMoveHandler = new dockspawn.EventHandler(window, 'mousemove', this.onMouseMoved.bind(this));
};

dockspawn.DockManager.prototype.onDialogDragEnded = function(sender, e)
{
    if (this.mouseMoveHandler)
    {
        this.mouseMoveHandler.cancel();
        delete this.mouseMoveHandler;
    }
    this.dockWheel.onDialogDropped(sender);
    this.dockWheel.hideWheel();
    delete this.dockWheel.activeDialog;
};

dockspawn.DockManager.prototype.onMouseMoved = function(e)
{
    this.dockWheel.activeNode = this._findNodeOnPoint(e.clientX, e.clientY);
};

/**
 * Perform a DFS on the dock model's tree to find the
 * deepest level panel (i.e. the top-most non-overlapping panel)
 * that is under the mouse cursor
 * Retuns null if no node is found under this point
 */
dockspawn.DockManager.prototype._findNodeOnPoint = function(x, y)
{
    var stack = [];
    stack.push(this.context.model.rootNode);
    var bestMatch;

    while (stack.length > 0)
    {
        var topNode = stack.pop();

        if (isPointInsideNode(x, y, topNode))
        {
            // This node contains the point.
            bestMatch = topNode;

            // Keep looking future down
            [].push.apply(stack, topNode.children);
        }
    }
    return bestMatch;
};

/** Dock the [dialog] to the left of the [referenceNode] node */
dockspawn.DockManager.prototype.dockDialogLeft = function(referenceNode, dialog)
{
    return this._requestDockDialog(referenceNode, dialog, this.layoutEngine.dockLeft.bind(this.layoutEngine));
};

/** Dock the [dialog] to the right of the [referenceNode] node */
dockspawn.DockManager.prototype.dockDialogRight = function(referenceNode, dialog)
{
    return this._requestDockDialog(referenceNode, dialog, this.layoutEngine.dockRight.bind(this.layoutEngine));
};

/** Dock the [dialog] above the [referenceNode] node */
dockspawn.DockManager.prototype.dockDialogUp = function(referenceNode, dialog)
{
    return this._requestDockDialog(referenceNode, dialog, this.layoutEngine.dockUp.bind(this.layoutEngine));
};

/** Dock the [dialog] below the [referenceNode] node */
dockspawn.DockManager.prototype.dockDialogDown = function(referenceNode, dialog)
{
    return this._requestDockDialog(referenceNode, dialog, this.layoutEngine.dockDown.bind(this.layoutEngine));
};

/** Dock the [dialog] as a tab inside the [referenceNode] node */
dockspawn.DockManager.prototype.dockDialogFill = function(referenceNode, dialog)
{
    return this._requestDockDialog(referenceNode, dialog, this.layoutEngine.dockFill.bind(this.layoutEngine));
};

/** Dock the [container] to the left of the [referenceNode] node */
dockspawn.DockManager.prototype.dockLeft = function(referenceNode, container, ratio)
{
    return this._requestDockContainer(referenceNode, container, this.layoutEngine.dockLeft.bind(this.layoutEngine), ratio);
};

/** Dock the [container] to the right of the [referenceNode] node */
dockspawn.DockManager.prototype.dockRight = function(referenceNode,  container, ratio)
{
    return this._requestDockContainer(referenceNode, container, this.layoutEngine.dockRight.bind(this.layoutEngine), ratio);
};

/** Dock the [container] above the [referenceNode] node */
dockspawn.DockManager.prototype.dockUp = function(referenceNode,  container, ratio)
{
    return this._requestDockContainer(referenceNode, container, this.layoutEngine.dockUp.bind(this.layoutEngine), ratio);
};

/** Dock the [container] below the [referenceNode] node */
dockspawn.DockManager.prototype.dockDown = function(referenceNode,  container, ratio)
{
    return this._requestDockContainer(referenceNode, container, this.layoutEngine.dockDown.bind(this.layoutEngine), ratio);
};

/** Dock the [container] as a tab inside the [referenceNode] node */
dockspawn.DockManager.prototype.dockFill = function(referenceNode, container)
{
    return this._requestDockContainer(referenceNode, container, this.layoutEngine.dockFill.bind(this.layoutEngine));
};

dockspawn.DockManager.prototype._requestDockDialog = function(referenceNode, dialog, layoutDockFunction)
{
    // Get the active dialog that was dragged on to the dock wheel
    var panel = dialog.panel;
    var newNode = new dockspawn.DockNode(panel);
    panel.prepareForDocking();
    dialog.destroy();
    layoutDockFunction(referenceNode, newNode);
    this.invalidate();
    return newNode;
};

dockspawn.DockManager.prototype._requestDockContainer = function(referenceNode, container, layoutDockFunction, ratio)
{
    // Get the active dialog that was dragged on to the dock wheel
    var newNode = new dockspawn.DockNode(container);
    if (container.containerType == "panel")
    {
        var panel = container;
        panel.prepareForDocking();
        removeNode(panel.elementPanel);
    }
    layoutDockFunction(referenceNode, newNode);

    if (ratio && newNode.parent &&
        (newNode.parent.container.containerType == "vertical" || newNode.parent.container.containerType == "horizontal"))
    {
        var splitter = newNode.parent.container;
        splitter.setContainerRatio(container, ratio);
    }

    this.rebuildLayout(this.context.model.rootNode);
    this.invalidate();
    return newNode;
};

/**
 * Undocks a panel and converts it into a floating dialog window
 * It is assumed that only leaf nodes (panels) can be undocked
 */
dockspawn.DockManager.prototype.requestUndockToDialog = function(container, event, dragOffset)
{
    var node = this._findNodeFromContainer(container);
    this.layoutEngine.undock(node);

    // Create a new dialog window for the undocked panel
    var dialog = new dockspawn.Dialog(node.container, this);

    // Adjust the relative position
    var dialogWidth = dialog.elementDialog.clientWidth;
    if (dragOffset.x > dialogWidth)
        dragOffset.x = 0.75 * dialogWidth;
    dialog.setPosition(
        event.clientX - dragOffset.x,
        event.clientY - dragOffset.y);
    dialog.draggable.onMouseDown(event);

    return dialog;
};

/** Undocks a panel and converts it into a floating dialog window
 * It is assumed that only leaf nodes (panels) can be undocked
 */
dockspawn.DockManager.prototype.requestUndock = function(container)
{
    var node = this._findNodeFromContainer(container);
    this.layoutEngine.undock(node);
};

/**
 * Removes a dock container from the dock layout hierarcy
 * Returns the node that was removed from the dock tree
 */
dockspawn.DockManager.prototype.requestRemove = function(container)
{
    var node = this._findNodeFromContainer(container);
    var parent = node.parent;
    node.detachFromParent();
    if (parent)
        this.rebuildLayout(parent);
    return node;
};

/** Finds the node that owns the specified [container] */
dockspawn.DockManager.prototype._findNodeFromContainer = function(container)
{
    //this.context.model.rootNode.debug_DumpTree();

    var stack = [];
    stack.push(this.context.model.rootNode);

    while (stack.length > 0)
    {
        var topNode = stack.pop();

        if (topNode.container === container)
            return topNode;
        [].push.apply(stack, topNode.children);
    }

    throw new dockspawn.Exception("Cannot find dock node belonging to the element");
};

dockspawn.DockManager.prototype.addLayoutListener = function(listener)
{
    this.layoutEventListeners.push(listener);
};

dockspawn.DockManager.prototype.removeLayoutListener = function(listener)
{
    this.layoutEventListeners.splice(this.layoutEventListeners.indexOf(listener), 1);
};

dockspawn.DockManager.prototype.suspendLayout = function()
{
    var self = this;
    this.layoutEventListeners.forEach(function(listener) { 
		if (listener.onSuspendLayout) listener.onSuspendLayout(self); 
	});
};

dockspawn.DockManager.prototype.resumeLayout = function()
{
    var self = this;
    this.layoutEventListeners.forEach(function(listener) { 
		if (listener.onResumeLayout) listener.onResumeLayout(self); 
	});
};

dockspawn.DockManager.prototype.notifyOnDock = function(dockNode)
{
    var self = this;
    this.layoutEventListeners.forEach(function(listener) { 
		if (listener.onDock) {
			listener.onDock(self, dockNode); 
		}
	});
};

dockspawn.DockManager.prototype.notifyOnUnDock = function(dockNode)
{
    var self = this;
    this.layoutEventListeners.forEach(function(listener) { 
		if (listener.onUndock) {
			listener.onUndock(self, dockNode); 
		}
	});
};

dockspawn.DockManager.prototype.saveState = function()
{
    var serializer = new dockspawn.DockGraphSerializer();
    return serializer.serialize(this.context.model);
};

dockspawn.DockManager.prototype.loadState = function(json)
{
    var deserializer = new dockspawn.DockGraphDeserializer(this);
    this.context.model = deserializer.deserialize(json);
    this.setModel(this.context.model);
};

//typedef void LayoutEngineDockFunction(dockspawn.DockNode referenceNode, dockspawn.DockNode newNode);

/**
* The Dock Manager notifies the listeners of layout changes so client containers that have
* costly layout structures can detach and reattach themself to avoid reflow
*/
//abstract class LayoutEventListener {
//void onSuspendLayout(dockspawn.DockManager dockManager);
//void onResumeLayout(dockspawn.DockManager dockManager);
//}

dockspawn.DockLayoutEngine = function(dockManager)
{
    this.dockManager = dockManager;
}

/** docks the [newNode] to the left of [referenceNode] */
dockspawn.DockLayoutEngine.prototype.dockLeft = function(referenceNode, newNode)
{
    this._performDock(referenceNode, newNode, "horizontal", true);
};

/** docks the [newNode] to the right of [referenceNode] */
dockspawn.DockLayoutEngine.prototype.dockRight = function(referenceNode, newNode) {
    this._performDock(referenceNode, newNode, "horizontal", false);
};

/** docks the [newNode] to the top of [referenceNode] */
dockspawn.DockLayoutEngine.prototype.dockUp = function(referenceNode, newNode) {
    this._performDock(referenceNode, newNode, "vertical", true);
};

/** docks the [newNode] to the bottom of [referenceNode] */
dockspawn.DockLayoutEngine.prototype.dockDown = function(referenceNode, newNode) {
    this._performDock(referenceNode, newNode, "vertical", false);
};

/** docks the [newNode] by creating a new tab inside [referenceNode] */
dockspawn.DockLayoutEngine.prototype.dockFill = function(referenceNode, newNode) {
    this._performDock(referenceNode, newNode, "fill", false);
};

dockspawn.DockLayoutEngine.prototype.undock = function(node)
{
    var parentNode = node.parent;
    if (!parentNode)
        throw new dockspawn.Exception("Cannot undock.  panel is not a leaf node");

    // Get the position of the node relative to it's siblings
    var siblingIndex = parentNode.children.indexOf(node);

    // Detach the node from the dock manager's tree hierarchy
    node.detachFromParent();

    // Fix the node's parent hierarchy
    if (parentNode.children.length < parentNode.container.minimumAllowedChildNodes) {
        // If the child count falls below the minimum threshold, destroy the parent and merge
        // the children with their grandparents
        var grandParent = parentNode.parent;
        for (var i = 0; i < parentNode.children.length; i++)
        {
            var otherChild = parentNode.children[i];
            if (grandParent)
            {
                // parent node is not a root node
                grandParent.addChildAfter(parentNode, otherChild);
                parentNode.detachFromParent();
                parentNode.container.destroy();
                grandParent.performLayout();
            }
            else
            {
                // Parent is a root node.
                // Make the other child the root node
                parentNode.detachFromParent();
                parentNode.container.destroy();
                this.dockManager.setRootNode(otherChild);
            }
        }
    }
    else
    {
        // the node to be removed has 2 or more other siblings. So it is safe to continue
        // using the parent composite container.
        parentNode.performLayout();

        // Set the next sibling as the active child (e.g. for a Tab host, it would select it as the active tab)
        if (parentNode.children.length > 0)
        {
            var nextActiveSibling = parentNode.children[Math.max(0, siblingIndex - 1)];
            parentNode.container.setActiveChild(nextActiveSibling.container);
        }
    }
    this.dockManager.invalidate();
	this.dockManager.notifyOnUnDock(node);
};

dockspawn.DockLayoutEngine.prototype._performDock = function(referenceNode, newNode, direction, insertBeforeReference)
{
    if (referenceNode.parent && referenceNode.parent.container.containerType == "fill")
        referenceNode = referenceNode.parent;

    if (direction == "fill" && referenceNode.container.containerType == "fill")
    {
        referenceNode.addChild(newNode);
        referenceNode.performLayout();
        referenceNode.container.setActiveChild(newNode.container);
        return;
    }

    // Check if reference node is root node
    var model = this.dockManager.context.model;
    if (referenceNode === model.rootNode)
    {
        var compositeContainer = this._createDockContainer(direction, newNode, referenceNode);
        var compositeNode = new dockspawn.DockNode(compositeContainer);

        if (insertBeforeReference)
        {
            compositeNode.addChild(newNode);
            compositeNode.addChild(referenceNode);
        }
        else
        {
            compositeNode.addChild(referenceNode);
            compositeNode.addChild(newNode);
        }

        // Attach the root node to the dock manager's DOM
		this.dockManager.setRootNode(compositeNode);
        this.dockManager.rebuildLayout(this.dockManager.context.model.rootNode);
        compositeNode.container.setActiveChild(newNode.container);
        return;
    }

    if (referenceNode.parent.container.containerType != direction) {
        var referenceParent = referenceNode.parent;

        // Get the dimensions of the reference node, for resizing later on
        var referenceNodeWidth = referenceNode.container.containerElement.clientWidth;
        var referenceNodeHeight = referenceNode.container.containerElement.clientHeight;

        // Get the dimensions of the reference node, for resizing later on
        var referenceNodeParentWidth = referenceParent.container.containerElement.clientWidth;
        var referenceNodeParentHeight = referenceParent.container.containerElement.clientHeight;

        // Replace the reference node with a new composite node with the reference and new node as it's children
        var compositeContainer = this._createDockContainer(direction, newNode, referenceNode);
        var compositeNode = new dockspawn.DockNode(compositeContainer);

        referenceParent.addChildAfter(referenceNode, compositeNode);
        referenceNode.detachFromParent();
        removeNode(referenceNode.container.containerElement);

        if (insertBeforeReference)
        {
            compositeNode.addChild(newNode);
            compositeNode.addChild(referenceNode);
        }
        else
        {
            compositeNode.addChild(referenceNode);
            compositeNode.addChild(newNode);
        }

        referenceParent.performLayout();
        compositeNode.performLayout();

        compositeNode.container.setActiveChild(newNode.container);
        compositeNode.container.resize(referenceNodeWidth, referenceNodeHeight);
        referenceParent.container.resize(referenceNodeParentWidth, referenceNodeParentHeight);
    }
    else
    {
        // Add as a sibling, since the parent of the reference node is of the right composite type
        var referenceParent = referenceNode.parent;
        if (insertBeforeReference)
            referenceParent.addChildBefore(referenceNode, newNode);
        else
            referenceParent.addChildAfter(referenceNode, newNode);
        referenceParent.performLayout();
        referenceParent.container.setActiveChild(newNode.container);
    }

    // force resize the panel
    var containerWidth = newNode.container.containerElement.clientWidth;
    var containerHeight = newNode.container.containerElement.clientHeight;
    newNode.container.resize(containerWidth, containerHeight);
	
	this.dockManager.notifyOnDock(newNode);
};

dockspawn.DockLayoutEngine.prototype._forceResizeCompositeContainer = function(container)
{
    var width = container.containerElement.clientWidth;
    var height = container.containerElement.clientHeight;
    container.resize(width, height);
};

dockspawn.DockLayoutEngine.prototype._createDockContainer = function(containerType, newNode, referenceNode)
{
    if (containerType == "horizontal")
        return new dockspawn.HorizontalDockContainer(this.dockManager, [newNode.container, referenceNode.container]);
    if (containerType == "vertical")
        return new dockspawn.VerticalDockContainer(this.dockManager, [newNode.container, referenceNode.container]);
    if (containerType == "fill")
        return new dockspawn.FillDockContainer(this.dockManager);
    throw new dockspawn.Exception("Failed to create dock container of type: " + containerType);
};


/**
 * Gets the bounds of the new node if it were to dock with the specified configuration
 * The state is not modified in this function.  It is used for showing a preview of where
 * the panel would be docked when hovered over a dock wheel button
 */
dockspawn.DockLayoutEngine.prototype.getDockBounds = function(referenceNode, containerToDock, direction, insertBeforeReference)
{
    var compositeNode; // The node that contains the splitter / fill node
    var childCount;
    var childPosition;
    if (direction == "fill")
    {
        // Since this is a fill operation, the highlight bounds is the same as the reference node
        // TODO: Create a tab handle highlight to show that it's going to be docked in a tab
        var targetElement = referenceNode.container.containerElement;
        var bounds = new Rectangle();
        bounds.x = targetElement.offsetLeft;
        bounds.y = targetElement.offsetTop;
        bounds.width = targetElement.clientWidth;
        bounds.height= targetElement.clientHeight;
        return bounds;
    }

    if (referenceNode.parent && referenceNode.parent.container.containerType == "fill")
        // Ignore the fill container's child and move one level up
        referenceNode = referenceNode.parent;

    // Flag to indicate of the renference node was replaced with a new composite node with 2 children
    var hierarchyModified = false;
    if (referenceNode.parent && referenceNode.parent.container.containerType == direction) {
        // The parent already is of the desired composite type.  Will be inserted as sibling to the reference node
        compositeNode = referenceNode.parent;
        childCount = compositeNode.children.length;
        childPosition = compositeNode.children.indexOf(referenceNode) + (insertBeforeReference ? 0 : 1);
    } else {
        // The reference node will be replaced with a new composite node of the desired type with 2 children
        compositeNode = referenceNode;
        childCount = 1;   // The newly inserted composite node will contain the reference node
        childPosition = (insertBeforeReference ? 0 : 1);
        hierarchyModified = true;
    }

    var splitBarSize = 5;  // TODO: Get from DOM
    var targetPanelSize = 0;
    var targetPanelStart = 0;
    if (direction == "vertical" || direction == "horizontal")
    {
        // Existing size of the composite container (without the splitter bars).
        // This will also be the final size of the composite (splitter / fill)
        // container after the new panel has been docked
        var compositeSize = this._getVaringDimension(compositeNode.container, direction) - (childCount - 1) * splitBarSize;

        // size of the newly added panel
        var newPanelOriginalSize = this._getVaringDimension(containerToDock, direction);
        var scaleMultiplier = compositeSize / (compositeSize + newPanelOriginalSize);

        // Size of the panel after it has been docked and scaled
        targetPanelSize = newPanelOriginalSize * scaleMultiplier;
        if (hierarchyModified)
            targetPanelStart = insertBeforeReference ? 0 : compositeSize * scaleMultiplier;
        else
        {
            for (var i = 0; i < childPosition; i++)
                targetPanelStart += this._getVaringDimension(compositeNode.children[i].container, direction);
            targetPanelStart *= scaleMultiplier;
        }
    }

    var bounds = new Rectangle();
    if (direction == "vertical")
    {
        bounds.x = compositeNode.container.containerElement.offsetLeft;
        bounds.y = compositeNode.container.containerElement.offsetTop + targetPanelStart;
        bounds.width = compositeNode.container.width;
        bounds.height = targetPanelSize;
    } else if (direction == "horizontal") {
        bounds.x = compositeNode.container.containerElement.offsetLeft + targetPanelStart;
        bounds.y = compositeNode.container.containerElement.offsetTop;
        bounds.width = targetPanelSize;
        bounds.height = compositeNode.container.height;
    }

    return bounds;
};

dockspawn.DockLayoutEngine.prototype._getVaringDimension = function(container, direction)
{
    if (direction == "vertical")
        return container.height;
    if (direction == "horizontal")
        return container.width;
    return 0;
};
dockspawn.DockManagerContext = function(dockManager)
{
    this.dockManager = dockManager;
    this.model = new dockspawn.DockModel();
    this.documentManagerView = new dockspawn.DocumentManagerContainer(this.dockManager);
};
/**
 * The Dock Model contains the tree hierarchy that represents the state of the
 * panel placement within the dock manager.
 */
dockspawn.DockModel = function()
{
    this.rootNode = this.documentManagerNode = undefined;
};

dockspawn.DockNode = function(container)
{
    /** The dock container represented by this node */
    this.container = container;
    this.children = [];
}

dockspawn.DockNode.prototype.detachFromParent = function()
{
    if (this.parent)
    {
        this.parent.removeChild(this);
        delete this.parent;
    }
};

dockspawn.DockNode.prototype.removeChild = function(childNode)
{
    var index = this.children.indexOf(childNode);
    if (index >= 0)
        this.children.splice(index, 1);
};

dockspawn.DockNode.prototype.addChild = function(childNode)
{
    childNode.detachFromParent();
    childNode.parent = this;
    this.children.push(childNode);
};

dockspawn.DockNode.prototype.addChildBefore = function(referenceNode, childNode)
{
    this._addChildWithDirection(referenceNode, childNode, true);
};

dockspawn.DockNode.prototype.addChildAfter = function(referenceNode, childNode)
{
    this._addChildWithDirection(referenceNode, childNode, false);
};

dockspawn.DockNode.prototype._addChildWithDirection = function(referenceNode, childNode, before)
{
    // Detach this node from it's parent first
    childNode.detachFromParent();
    childNode.parent = this;

    var referenceIndex = this.children.indexOf(referenceNode);
    var preList = this.children.slice(0, referenceIndex);
    var postList = this.children.slice(referenceIndex + 1, this.children.length);

    this.children = preList.slice(0);
    if (before)
    {
        this.children.push(childNode);
        this.children.push(referenceNode);
    }
    else
    {
        this.children.push(referenceNode);
        this.children.push(childNode);
    }
    Array.prototype.push.apply(this.children, postList);
};

dockspawn.DockNode.prototype.performLayout = function()
{
    var childContainers = this.children.map(function(childNode) { return childNode.container; });
    this.container.performLayout(childContainers);
};

dockspawn.DockNode.prototype.debug_DumpTree = function(indent)
{
    if (indent === undefined)
        indent = 0;

    var message = this.container.name;
    for (var i = 0; i < indent; i++)
        message = "\t" + message;

    var parentType = this.parent === undefined ? "null" : this.parent.container.containerType;
    console.log(">>" + message + " [" + parentType + "]");

    this.children.forEach(function(childNode) { childNode.debug_DumpTree(indent + 1) });
};
/**
 * Manages the dock overlay buttons that are displayed over the dock manager
 */
dockspawn.DockWheel = function(dockManager)
{
    this.dockManager = dockManager;
    this.elementMainWheel = document.createElement("div");    // Contains the main wheel's 5 dock buttons
    this.elementSideWheel = document.createElement("div");    // Contains the 4 buttons on the side
    this.wheelItems = {};
    var wheelTypes = [
        "left", "right", "top", "down", "fill",     // Main dock wheel buttons
        "left-s", "right-s", "top-s", "down-s"      // Buttons on the extreme 4 sides
    ];
    var self = this;
    wheelTypes.forEach(function(wheelType)
    {
        self.wheelItems[wheelType] = new DockWheelItem(self, wheelType);
        if (wheelType.substr(-2, 2) == "-s")
            // Side button
            self.elementSideWheel.appendChild(self.wheelItems[wheelType].element);
        else
            // Main dock wheel button
            self.elementMainWheel.appendChild(self.wheelItems[wheelType].element);
    });

    var zIndex = 100000;
    this.elementMainWheel.classList.add("dock-wheel-base");
    this.elementSideWheel.classList.add("dock-wheel-base");
    this.elementMainWheel.style.zIndex = zIndex + 1;
    this.elementSideWheel.style.zIndex = zIndex;
    this.elementPanelPreview = document.createElement("div");  // Used for showing the preview of where the panel would be docked
    this.elementPanelPreview.classList.add("dock-wheel-panel-preview");
    this.elementPanelPreview.style.zIndex = zIndex - 1;
    this.activeDialog = undefined;  // The dialog being dragged, when the wheel is visible
    this._activeNode = undefined;
    this._visible = false;
};

/** The node over which the dock wheel is being displayed on */
Object.defineProperty(dockspawn.DockWheel.prototype, "activeNode", {
    get: function() { return this._activeNode; },
    set: function(value)
    {
        var previousValue = this._activeNode;
        this._activeNode = value;

        if (previousValue !== this._activeNode)
        {
            // The active node has been changed.
            // Reattach the wheel to the new node's element and show it again
            if (this._visible)
                this.showWheel();
        }
    }
});

dockspawn.DockWheel.prototype.showWheel = function()
{
    this._visible = true;
    if (!this.activeNode)
    {
        // No active node selected. make sure the wheel is invisible
        removeNode(this.elementMainWheel);
        removeNode(this.elementSideWheel);
        return;
    }
    var element = this.activeNode.container.containerElement;
    var containerWidth = element.clientWidth;
    var containerHeight = element.clientHeight;
    var baseX = Math.floor(containerWidth / 2) + element.offsetLeft;
    var baseY = Math.floor(containerHeight / 2) + element.offsetTop;
    this.elementMainWheel.style.left = baseX + "px";
    this.elementMainWheel.style.top = baseY + "px";

    // The positioning of the main dock wheel buttons is done automatically through CSS
    // Dynamically calculate the positions of the buttons on the extreme sides of the dock manager
    var sideMargin = 20;
    var dockManagerWidth = this.dockManager.element.clientWidth;
    var dockManagerHeight = this.dockManager.element.clientHeight;
    var dockManagerOffsetX = this.dockManager.element.offsetLeft;
    var dockManagerOffsetY = this.dockManager.element.offsetTop;

    removeNode(this.elementMainWheel);
    removeNode(this.elementSideWheel);
    element.appendChild(this.elementMainWheel);
    this.dockManager.element.appendChild(this.elementSideWheel);

    this._setWheelButtonPosition("left-s",   sideMargin, -dockManagerHeight / 2);
    this._setWheelButtonPosition("right-s",  dockManagerWidth - sideMargin * 2, -dockManagerHeight / 2);
    this._setWheelButtonPosition("top-s",    dockManagerWidth / 2, -dockManagerHeight + sideMargin);
    this._setWheelButtonPosition("down-s",   dockManagerWidth / 2, -sideMargin);
};

dockspawn.DockWheel.prototype._setWheelButtonPosition = function(wheelId, left, top)
{
    var item = this.wheelItems[wheelId];
    var itemHalfWidth = item.element.clientWidth / 2;
    var itemHalfHeight = item.element.clientHeight / 2;

    var x = Math.floor(left - itemHalfWidth);
    var y = Math.floor(top - itemHalfHeight);
//    item.element.style.left = "${x}px";
//    item.element.style.top = "${y}px";
    item.element.style.marginLeft = x + "px";
    item.element.style.marginTop = y + "px";
};

dockspawn.DockWheel.prototype.hideWheel = function()
{
    this._visible = false;
    this.activeNode = undefined;
    removeNode(this.elementMainWheel);
    removeNode(this.elementSideWheel);
    removeNode(this.elementPanelPreview);

    // deactivate all wheels
    for (var wheelType in this.wheelItems)
        this.wheelItems[wheelType].active = false;
};

dockspawn.DockWheel.prototype.onMouseOver = function(wheelItem, e)
{
    if (!this.activeDialog)
        return;

    // Display the preview panel to show where the panel would be docked
    var rootNode = this.dockManager.context.model.rootNode;
    var bounds;
    if (wheelItem.id == "top") {
        bounds = this.dockManager.layoutEngine.getDockBounds(this.activeNode, this.activeDialog.panel, "vertical", true);
    } else if (wheelItem.id == "down") {
        bounds = this.dockManager.layoutEngine.getDockBounds(this.activeNode, this.activeDialog.panel, "vertical", false);
    } else if (wheelItem.id == "left") {
        bounds = this.dockManager.layoutEngine.getDockBounds(this.activeNode, this.activeDialog.panel, "horizontal", true);
    } else if (wheelItem.id == "right") {
        bounds = this.dockManager.layoutEngine.getDockBounds(this.activeNode, this.activeDialog.panel, "horizontal", false);
    } else if (wheelItem.id == "fill") {
        bounds = this.dockManager.layoutEngine.getDockBounds(this.activeNode, this.activeDialog.panel, "fill", false);
    } else if (wheelItem.id == "top-s") {
        bounds = this.dockManager.layoutEngine.getDockBounds(rootNode, this.activeDialog.panel, "vertical", true);
    } else if (wheelItem.id == "down-s") {
        bounds = this.dockManager.layoutEngine.getDockBounds(rootNode, this.activeDialog.panel, "vertical", false);
    } else if (wheelItem.id == "left-s") {
        bounds = this.dockManager.layoutEngine.getDockBounds(rootNode, this.activeDialog.panel, "horizontal", true);
    } else if (wheelItem.id == "right-s") {
        bounds = this.dockManager.layoutEngine.getDockBounds(rootNode, this.activeDialog.panel, "horizontal", false);
    }

    if (bounds)
    {
        this.dockManager.element.appendChild(this.elementPanelPreview);
        this.elementPanelPreview.style.left = Math.round(bounds.x) + "px";
        this.elementPanelPreview.style.top = Math.round(bounds.y) + "px";
        this.elementPanelPreview.style.width = Math.round(bounds.width) + "px";
        this.elementPanelPreview.style.height = Math.round(bounds.height) + "px";
    }
};

dockspawn.DockWheel.prototype.onMouseOut = function(wheelItem, e)
{
    removeNode(this.elementPanelPreview);
};

/**
 * Called if the dialog is dropped in a dock panel.
 * The dialog might not necessarily be dropped in one of the dock wheel buttons,
 * in which case the request will be ignored
 */
dockspawn.DockWheel.prototype.onDialogDropped = function(dialog)
{
    // Check if the dialog was dropped in one of the wheel items
    var wheelItem = this._getActiveWheelItem();
    if (wheelItem)
        this._handleDockRequest(wheelItem, dialog);
};

/**
 * Returns the wheel item which has the mouse cursor on top of it
 */
dockspawn.DockWheel.prototype._getActiveWheelItem = function()
{
    for (var wheelType in this.wheelItems)
    {
        var wheelItem = this.wheelItems[wheelType];
        if (wheelItem.active)
            return wheelItem;
    }
    return undefined;
};

dockspawn.DockWheel.prototype._handleDockRequest = function(wheelItem, dialog)
{
    if (!this.activeNode)
        return;
    if (wheelItem.id == "left") {
        this.dockManager.dockDialogLeft(this.activeNode, dialog);
    } else if (wheelItem.id == "right") {
        this.dockManager.dockDialogRight(this.activeNode, dialog);
    } else if (wheelItem.id == "top") {
        this.dockManager.dockDialogUp(this.activeNode, dialog);
    } else if (wheelItem.id == "down") {
        this.dockManager.dockDialogDown(this.activeNode, dialog);
    } else if (wheelItem.id == "fill") {
        this.dockManager.dockDialogFill(this.activeNode, dialog);
    } else if (wheelItem.id == "left-s") {
        this.dockManager.dockDialogLeft(this.dockManager.context.model.rootNode, dialog);
    } else if (wheelItem.id == "right-s") {
        this.dockManager.dockDialogRight(this.dockManager.context.model.rootNode, dialog);
    } else if (wheelItem.id == "top-s") {
        this.dockManager.dockDialogUp(this.dockManager.context.model.rootNode, dialog);
    } else if (wheelItem.id == "down-s") {
        this.dockManager.dockDialogDown(this.dockManager.context.model.rootNode, dialog);
    }
};

function DockWheelItem(wheel, id)
{
    this.wheel = wheel;
    this.id = id;
    var wheelType = id.replace("-s", "");
    this.element = document.createElement("div");
    this.element.classList.add("dock-wheel-item");
    this.element.classList.add("disable-selection");
    this.element.classList.add("dock-wheel-" + wheelType);
    this.element.classList.add("dock-wheel-" + wheelType + "-icon");
    this.hoverIconClass = "dock-wheel-" + wheelType + "-icon-hover";
    this.mouseOverHandler = new dockspawn.EventHandler(this.element, 'mouseover', this.onMouseMoved.bind(this));
    this.mouseOutHandler = new dockspawn.EventHandler(this.element, 'mouseout', this.onMouseOut.bind(this));
    this.active = false;    // Becomes active when the mouse is hovered over it
};

DockWheelItem.prototype.onMouseMoved = function(e)
{
    this.active = true;
    this.element.classList.add(this.hoverIconClass);
    this.wheel.onMouseOver(this, e);
};

DockWheelItem.prototype.onMouseOut = function(e)
{
    this.active = false;
    this.element.classList.remove(this.hoverIconClass);
    this.wheel.onMouseOut(this, e);
};

dockspawn.FillDockContainer = function(dockManager, tabStripDirection)
{
    if (arguments.length == 0)
        return;

    if (tabStripDirection === undefined)
        tabStripDirection = dockspawn.TabHost.DIRECTION_BOTTOM;

    this.dockManager = dockManager;
    this.tabOrientation = tabStripDirection;
    this.name = getNextId("fill_");
    this.element = document.createElement("div");
    this.containerElement = this.element;
    this.containerType = "fill";
    this.minimumAllowedChildNodes = 2;
    this.element.classList.add("dock-container");
    this.element.classList.add("dock-container-fill");
    this.tabHost = new dockspawn.TabHost(this.tabOrientation);
    this.element.appendChild(this.tabHost.hostElement);
}

dockspawn.FillDockContainer.prototype.setActiveChild = function(child)
{
    this.tabHost.setActiveTab(child);
};

dockspawn.FillDockContainer.prototype.resize = function(width, height)
{
    this.element.style.width = width + "px";
    this.element.style.height = height + "px";
    this.tabHost.resize(width, height);
};

dockspawn.FillDockContainer.prototype.performLayout = function(children)
{
    this.tabHost.performLayout(children);
};

dockspawn.FillDockContainer.prototype.destroy = function()
{
    if (removeNode(this.element))
        delete this.element;
};

dockspawn.FillDockContainer.prototype.saveState = function(state)
{
    state.width = this.width;
    state.height = this.height;
};

dockspawn.FillDockContainer.prototype.loadState = function(state)
{
    this.width = state.width;
    this.height = state.height;
};

Object.defineProperty(dockspawn.FillDockContainer.prototype, "width", {
    get: function() { return this.element.clientWidth; },
    set: function(value) { this.element.style.width = value + "px" }
});

Object.defineProperty(dockspawn.FillDockContainer.prototype, "height", {
    get: function() { return this.element.clientHeight; },
    set: function(value) { this.element.style.height = value + "px" }
});

/**
 * The document manager is then central area of the dock layout hierarchy.
 * This is where more important panels are placed (e.g. the text editor in an IDE,
 * 3D view in a modelling package etc
 */
dockspawn.DocumentManagerContainer = function(dockManager)
{
    dockspawn.FillDockContainer.call(this, dockManager, dockspawn.TabHost.DIRECTION_TOP);
    this.minimumAllowedChildNodes = 0;
    this.element.classList.add("document-manager");
    this.tabHost.createTabPage = this._createDocumentTabPage;
    this.tabHost.displayCloseButton = true;
};
dockspawn.DocumentManagerContainer.prototype = new dockspawn.FillDockContainer();
dockspawn.DocumentManagerContainer.prototype.constructor = dockspawn.DocumentManagerContainer;

dockspawn.DocumentManagerContainer.prototype._createDocumentTabPage = function(tabHost, container)
{
    return new dockspawn.DocumentTabPage(tabHost, container);
};

dockspawn.DocumentManagerContainer.prototype.saveState = function(state)
{
    dockspawn.FillDockContainer.prototype.saveState.call(this, state);
    state.documentManager = true;
};

/** Returns the selected document tab */
dockspawn.DocumentManagerContainer.prototype.selectedTab = function()
{
    return this.tabHost.activeTab;
};

/**
 * Specialized tab page that doesn't display the panel's frame when docked in a tab page
 */
dockspawn.DocumentTabPage = function(host, container)
{
    dockspawn.TabPage.call(this, host, container);

    // If the container is a panel, extract the content element and set it as the tab's content
    if (this.container.containerType == "panel")
    {
        this.panel = container;
        this.containerElement = this.panel.elementContent;

        // detach the container element from the panel's frame.
        // It will be reattached when this tab page is destroyed
        // This enables the panel's frame (title bar etc) to be hidden
        // inside the tab page
        removeNode(this.containerElement);
    }
};
dockspawn.DocumentTabPage.prototype = new dockspawn.TabPage();
dockspawn.DocumentTabPage.prototype.constructor = dockspawn.DocumentTabPage;

dockspawn.DocumentTabPage.prototype.destroy = function()
{
    dockspawn.TabPage.prototype.destroy.call(this);

    // Restore the panel content element back into the panel frame
    removeNode(this.containerElement);
    this.panel.elementContentHost.appendChild(this.containerElement);
};
/**
 * A splitter panel manages the child containers inside it with splitter bars.
 * It can be stacked horizontally or vertically
 */
dockspawn.SplitterPanel = function(childContainers, stackedVertical)
{
    this.childContainers = childContainers;
    this.stackedVertical = stackedVertical;
    this.panelElement = document.createElement('div');
    this.spiltterBars = [];
    this._buildSplitterDOM();
};

dockspawn.SplitterPanel.prototype._buildSplitterDOM = function()
{
    if (this.childContainers.length <= 1)
        throw new dockspawn.Exception("Splitter panel should contain atleast 2 panels");

    this.spiltterBars = [];
    for (var i = 0; i < this.childContainers.length - 1; i++)
    {
        var previousContainer = this.childContainers[i];
        var nextContainer = this.childContainers[i + 1];
        var splitterBar = new dockspawn.SplitterBar(previousContainer, nextContainer, this.stackedVertical);
        this.spiltterBars.push(splitterBar);

        // Add the container and split bar to the panel's base div element
        this._insertContainerIntoPanel(previousContainer);
        this.panelElement.appendChild(splitterBar.barElement);
    }
    this._insertContainerIntoPanel(this.childContainers.slice(-1)[0]);
};

dockspawn.SplitterPanel.prototype.performLayout = function(children)
{
    this.removeFromDOM();

    // rebuild
    this.childContainers = children;
    this._buildSplitterDOM();
};

dockspawn.SplitterPanel.prototype.removeFromDOM = function()
{
    this.childContainers.forEach(function(container)
    {
        if (container.containerElement)
        {
            container.containerElement.classList.remove("splitter-container-vertical");
            container.containerElement.classList.remove("splitter-container-horizontal");
            removeNode(container.containerElement);
        }
    });
    this.spiltterBars.forEach(function(bar) { removeNode(bar.barElement); });
};

dockspawn.SplitterPanel.prototype.destroy = function()
{
    this.removeFromDOM();
    this.panelElement.parentNode.removeChild(this.panelElement);
};

dockspawn.SplitterPanel.prototype._insertContainerIntoPanel = function(container)
{
    if (!container)
    {
        console.log('undefined');
    }

    removeNode(container.containerElement);
    this.panelElement.appendChild(container.containerElement);
    container.containerElement.classList.add(this.stackedVertical ? "splitter-container-vertical" : "splitter-container-horizontal");
};

/**
 * Sets the percentage of space the specified [container] takes in the split panel
 * The percentage is specified in [ratio] and is between 0..1
 */
dockspawn.SplitterPanel.prototype.setContainerRatio = function(container, ratio)
{
    var splitPanelSize = this.stackedVertical ? this.panelElement.clientHeight : this.panelElement.clientWidth;
    var newContainerSize = splitPanelSize * ratio;
    var barSize = this.stackedVertical ? this.spiltterBars[0].barElement.clientHeight : this.spiltterBars[0].barElement.clientWidth;

    var otherPanelSizeQuota = splitPanelSize - newContainerSize - barSize * this.spiltterBars.length;
    var otherPanelScaleMultipler = otherPanelSizeQuota / splitPanelSize;

    for (var i = 0; i < this.childContainers.length; i++)
    {
        var child = this.childContainers[i];
        var size;
        if (child !== container)
        {
            size = this.stackedVertical ? child.containerElement.clientHeight : child.containerElement.clientWidth;
            size *= otherPanelScaleMultipler;
        }
        else
            size = newContainerSize;

        if (this.stackedVertical)
            child.resize(child.width, Math.floor(size));
        else
            child.resize(Math.floor(size), child.height);
    }
};

dockspawn.SplitterPanel.prototype.resize = function(width, height)
{
    if (this.childContainers.length <= 1)
        return;

    // Adjust the fixed dimension that is common to all (i.e. width, if stacked vertical; height, if stacked horizontally)
    for (var i = 0; i < this.childContainers.length; i++)
    {
        var childContainer = this.childContainers[i];
        if (this.stackedVertical)
            childContainer.resize(width, childContainer.height);
        else
            childContainer.resize(childContainer.width, height);

        if (i < this.spiltterBars.length) {
            var splitBar = this.spiltterBars[i];
            if (this.stackedVertical)
                splitBar.barElement.style.width = width + "px";
            else
                splitBar.barElement.style.height = height + "px";
        }
    }

    // Adjust the varying dimension
    var totalChildPanelSize = 0;
    // Find out how much space existing child containers take up (excluding the splitter bars)
    var self = this;
    this.childContainers.forEach(function(container)
    {
        var size = self.stackedVertical ?
            container.height :
            container.width;
        totalChildPanelSize += size;
    });

    // Get the thickness of the bar
    var barSize = this.stackedVertical ? this.spiltterBars[0].barElement.clientHeight : this.spiltterBars[0].barElement.clientWidth;

    // Find out how much space existing child containers will take after being resized (excluding the splitter bars)
    var targetTotalChildPanelSize = this.stackedVertical ? height : width;
    targetTotalChildPanelSize -= barSize * this.spiltterBars.length;

    // Get the scale multiplier
    totalChildPanelSize = Math.max(totalChildPanelSize, 1);
    var scaleMultiplier = targetTotalChildPanelSize / totalChildPanelSize;

    // Update the size with this multiplier
    var updatedTotalChildPanelSize = 0;
    for (var i = 0; i < this.childContainers.length; i++)
    {
        var child = this.childContainers[i];
        var original = this.stackedVertical ?
            child.containerElement.clientHeight :
            child.containerElement.clientWidth;

        var newSize = Math.floor(original * scaleMultiplier);
        updatedTotalChildPanelSize += newSize;

        // If this is the last node, add any extra pixels to fix the rounding off errors and match the requested size
        if (i == this.childContainers.length - 1)
            newSize += targetTotalChildPanelSize - updatedTotalChildPanelSize;

        // Set the size of the panel
        if (this.stackedVertical)
            child.resize(child.width, newSize);
        else
            child.resize(newSize, child.height);
    }

    this.panelElement.style.width = width + "px";
    this.panelElement.style.height = height + "px";
};

dockspawn.SplitterDockContainer = function(name, dockManager, childContainers)
{
    // for prototype inheritance purposes only
    if (arguments.length == 0)
        return;

    this.name = name;
    this.dockManager = dockManager;
    this.splitterPanel = new dockspawn.SplitterPanel(childContainers, this.stackedVertical);
    this.containerElement = this.splitterPanel.panelElement;
    this.minimumAllowedChildNodes = 2;
}

dockspawn.SplitterDockContainer.prototype.resize = function(width, height)
{
//    if (_cachedWidth == _cachedWidth && _cachedHeight == _height) {
//      // No need to resize
//      return;
//    }
    this.splitterPanel.resize(width, height);
    this._cachedWidth = width;
    this._cachedHeight = height;
};

dockspawn.SplitterDockContainer.prototype.performLayout = function(childContainers)
{
    this.splitterPanel.performLayout(childContainers);
};

dockspawn.SplitterDockContainer.prototype.setActiveChild = function(child)
{
};

dockspawn.SplitterDockContainer.prototype.destroy = function()
{
    this.splitterPanel.destroy();
};

/**
 * Sets the percentage of space the specified [container] takes in the split panel
 * The percentage is specified in [ratio] and is between 0..1
 */
dockspawn.SplitterDockContainer.prototype.setContainerRatio = function(container, ratio)
{
    this.splitterPanel.setContainerRatio(container, ratio);
    this.resize(this.width, this.height);
};

dockspawn.SplitterDockContainer.prototype.saveState = function(state)
{
    state.width = this.width;
    state.height = this.height;
};

dockspawn.SplitterDockContainer.prototype.loadState = function(state)
{
    this.resize(state.width, state.height);
};

Object.defineProperty(dockspawn.SplitterDockContainer.prototype, "width", {
    get: function()
    {
        if (this._cachedWidth === undefined)
            this._cachedWidth = this.splitterPanel.panelElement.clientWidth;
        return this._cachedWidth;
    }
});

Object.defineProperty(dockspawn.SplitterDockContainer.prototype, "height", {
    get: function()
    {
        if (this._cachedHeight === undefined)
            this._cachedHeight = this.splitterPanel.panelElement.clientHeight;
        return this._cachedHeight;
    }
});

dockspawn.HorizontalDockContainer = function(dockManager, childContainers)
{
    this.stackedVertical = false;
    dockspawn.SplitterDockContainer.call(this, getNextId("horizontal_splitter_"), dockManager, childContainers);
    this.containerType = "horizontal";
};
dockspawn.HorizontalDockContainer.prototype = new dockspawn.SplitterDockContainer();
dockspawn.HorizontalDockContainer.prototype.constructor = dockspawn.HorizontalDockContainer;
/**
 * This dock container wraps the specified element on a panel frame with a title bar and close button
 */
dockspawn.PanelContainer = function(elementContent, dockManager, title)
{
    if (!title)
        title = "Panel";
    this.elementContent = elementContent;
    this.dockManager = dockManager;
    this.title = title;
    this.containerType = "panel";
    this.iconName = "fa fa-arrow-circle-right";
    this.minimumAllowedChildNodes = 0;
    this._floatingDialog = undefined;
    this._initialize();
};

Object.defineProperty(dockspawn.PanelContainer.prototype, "floatingDialog", {
    get: function() { return this._floatingDialog; },
    set: function(value)
    {
        this._floatingDialog = value;
        var canUndock = (this._floatingDialog === undefined);
        this.undockInitiator.enabled = canUndock;
    }
});

dockspawn.PanelContainer.loadFromState = function(state, dockManager)
{
    var elementName = state.element;
    var elementContent = document.getElementById(elementName);
    var ret = new dockspawn.PanelContainer(elementContent, dockManager);
    ret.elementContent = elementContent;
    ret._initialize();
    ret.loadState(state);
    return ret;
};

dockspawn.PanelContainer.prototype.saveState = function(state)
{
    state.element = this.elementContent.id;
    state.width = this.width;
    state.height = this.height;
};

dockspawn.PanelContainer.prototype.loadState = function(state)
{
    this.width = state.width;
    this.height = state.height;
    this.resize(this.width, this.height);
};

dockspawn.PanelContainer.prototype.setActiveChild = function(child)
{
};

Object.defineProperty(dockspawn.PanelContainer.prototype, "containerElement", {
    get: function() { return this.elementPanel; }
});

dockspawn.PanelContainer.prototype._initialize = function()
{
    this.name = getNextId("panel_");
    this.elementPanel = document.createElement('div');
    this.elementTitle = document.createElement('div');
    this.elementTitleText = document.createElement('div');
    this.elementContentHost = document.createElement('div');
    this.elementButtonClose = document.createElement('div');

    this.elementPanel.appendChild(this.elementTitle);
    this.elementTitle.appendChild(this.elementTitleText);
    this.elementTitle.appendChild(this.elementButtonClose);
    this.elementButtonClose.innerHTML = '<i class="fa fa-remove"></i>';
    this.elementButtonClose.classList.add("panel-titlebar-button-close");
    this.elementPanel.appendChild(this.elementContentHost);

    this.elementPanel.classList.add("panel-base");
    this.elementTitle.classList.add("panel-titlebar");
    this.elementTitle.classList.add("disable-selection");
    this.elementTitleText.classList.add("panel-titlebar-text");
    this.elementContentHost.classList.add("panel-content");

    // set the size of the dialog elements based on the panel's size
    var panelWidth = this.elementContent.clientWidth;
    var panelHeight = this.elementContent.clientHeight;
    var titleHeight = this.elementTitle.clientHeight;
    this._setPanelDimensions(panelWidth, panelHeight + titleHeight);

    // Add the panel to the body
    document.body.appendChild(this.elementPanel);

    this.closeButtonClickedHandler = new dockspawn.EventHandler(this.elementButtonClose, 'click', this.onCloseButtonClicked.bind(this));

    removeNode(this.elementContent);
    this.elementContentHost.appendChild(this.elementContent);

    // Extract the title from the content element's attribute
    var contentTitle = this.elementContent.getAttribute('caption');
    var contentIcon = this.elementContent.getAttribute('icon');
    if (contentTitle != null) this.title = contentTitle;
    if (contentIcon != null) this.iconName = contentIcon;
    this._updateTitle();

    this.undockInitiator = new dockspawn.UndockInitiator(this.elementTitle, this.performUndockToDialog.bind(this));
    //delete this.floatingDialog;
};

dockspawn.PanelContainer.prototype.destroy = function()
{
    removeNode(this.elementPanel);
    if (this.closeButtonClickedHandler)
    {
        this.closeButtonClickedHandler.cancel();
        delete this.closeButtonClickedHandler;
    }
	if( this.__onDestroy ) this.__onDestroy();
};

/**
 * Undocks the panel and and converts it to a dialog box
 */
dockspawn.PanelContainer.prototype.performUndockToDialog = function(e, dragOffset)
{
    this.undockInitiator.enabled = false;
    return this.dockManager.requestUndockToDialog(this, e, dragOffset);
};

/**
 * Undocks the container and from the layout hierarchy
 * The container would be removed from the DOM
 */
dockspawn.PanelContainer.prototype.performUndock = function()
{
    this.undockInitiator.enabled = false;
    this.dockManager.requestUndock(this);
};

dockspawn.PanelContainer.prototype.prepareForDocking = function()
{
    this.undockInitiator.enabled = true;
};

Object.defineProperty(dockspawn.PanelContainer.prototype, "width", {
    get: function() { return this._cachedWidth; },
    set: function(value)
    {
        if (value !== this._cachedWidth)
        {
            this._cachedWidth = value;
            this.elementPanel.style.width = value + "px";
        }
    }
});

Object.defineProperty(dockspawn.PanelContainer.prototype, "height", {
    get: function() { return this._cachedHeight; },
    set: function(value)
    {
        if (value !== this._cachedHeight)
        {
            this._cachedHeight = value;
            this.elementPanel.style.height = value + "px";
        }
    }
});

dockspawn.PanelContainer.prototype.resize = function(width,  height)
{
    if (this._cachedWidth == width && this._cachedHeight == height)
    {
        // Already in the desired size
        return;
    }
    this._setPanelDimensions(width, height);
    this._cachedWidth = width;
    this._cachedHeight = height;
};

dockspawn.PanelContainer.prototype._setPanelDimensions = function(width, height)
{
    this.elementTitle.style.width = width + "px";
    this.elementContentHost.style.width = width + "px";
    this.elementContent.style.width = width + "px";
    this.elementPanel.style.width = width + "px";

    var titleBarHeight = this.elementTitle.clientHeight;
    var contentHeight = height - titleBarHeight;
    this.elementContentHost.style.height = contentHeight + "px";
    this.elementContent.style.height = contentHeight + "px";
    this.elementPanel.style.height = height + "px";
};

dockspawn.PanelContainer.prototype.setTitle = function(title)
{
    this.title = title;
    this._updateTitle();
    if (this.onTitleChanged)
        this.onTitleChanged(this, title);
};

dockspawn.PanelContainer.prototype.setTitleIcon = function(iconName)
{
    this.iconName = iconName;
    this._updateTitle();
};

dockspawn.PanelContainer.prototype._updateTitle = function()
{
    this.elementTitleText.innerHTML = '<i class="' + this.iconName + '"></i> ' + this.title;
};

dockspawn.PanelContainer.prototype.getRawTitle = function()
{
    return this.elementTitleText.innerHTML;
};

dockspawn.PanelContainer.prototype.performLayout = function(children)
{
};

dockspawn.PanelContainer.prototype.onCloseButtonClicked = function(e)
{
    if (this.floatingDialog)
        this.floatingDialog.destroy();
    else
        this.performUndock();
    this.destroy();
};

dockspawn.VerticalDockContainer = function(dockManager, childContainers)
{
    this.stackedVertical = true;
    dockspawn.SplitterDockContainer.call(this, getNextId("vertical_splitter_"), dockManager, childContainers);
    this.containerType = "vertical";
};
dockspawn.VerticalDockContainer.prototype = new dockspawn.SplitterDockContainer();
dockspawn.VerticalDockContainer.prototype.constructor = dockspawn.VerticalDockContainer;
dockspawn.SplitterBar = function(previousContainer, nextContainer, stackedVertical)
{
    this.previousContainer = previousContainer; // The panel to the left/top side of the bar, depending on the bar orientation
    this.nextContainer = nextContainer;         // The panel to the right/bottom side of the bar, depending on the bar orientation
    this.stackedVertical = stackedVertical;
    this.barElement = document.createElement('div');
    this.barElement.classList.add(stackedVertical ? "splitbar-horizontal" : "splitbar-vertical");
    this.mouseDownHandler = new dockspawn.EventHandler(this.barElement, 'mousedown', this.onMouseDown.bind(this));
    this.minPanelSize = 50; // TODO: Get from container configuration
    this.readyToProcessNextDrag = true;
};

dockspawn.SplitterBar.prototype.onMouseDown = function(e)
{
    this._startDragging(e);
};

dockspawn.SplitterBar.prototype.onMouseUp = function(e)
{
    this._stopDragging(e);
};

dockspawn.SplitterBar.prototype.onMouseMoved = function(e)
{
    if (!this.readyToProcessNextDrag)
        return;
    this.readyToProcessNextDrag = false;

    var dockManager = this.previousContainer.dockManager;
    dockManager.suspendLayout();
    var dx = e.pageX - this.previousMouseEvent.pageX;
    var dy = e.pageY - this.previousMouseEvent.pageY;
    this._performDrag(dx, dy);
    this.previousMouseEvent = e;
    this.readyToProcessNextDrag = true;
    dockManager.resumeLayout();
};

dockspawn.SplitterBar.prototype._performDrag = function(dx, dy)
{
    var previousWidth = this.previousContainer.containerElement.clientWidth;
    var previousHeight = this.previousContainer.containerElement.clientHeight;
    var nextWidth = this.nextContainer.containerElement.clientWidth;
    var nextHeight = this.nextContainer.containerElement.clientHeight;

    var previousPanelSize = this.stackedVertical ? previousHeight : previousWidth;
    var nextPanelSize = this.stackedVertical ? nextHeight : nextWidth;
    var deltaMovement = this.stackedVertical ? dy : dx;
    var newPreviousPanelSize = previousPanelSize + deltaMovement;
    var newNextPanelSize = nextPanelSize - deltaMovement;

    if (newPreviousPanelSize < this.minPanelSize || newNextPanelSize < this.minPanelSize)
    {
        // One of the panels is smaller than it should be.
        // In that case, check if the small panel's size is being increased
        var continueProcessing = (newPreviousPanelSize < this.minPanelSize && newPreviousPanelSize > previousPanelSize) ||
            (newNextPanelSize < this.minPanelSize && newNextPanelSize > nextPanelSize);

        if (!continueProcessing)
            return;
    }

    if (this.stackedVertical)
    {
        this.previousContainer.resize(previousWidth, newPreviousPanelSize);
        this.nextContainer.resize(nextWidth, newNextPanelSize);
    }
    else
    {
        this.previousContainer.resize(newPreviousPanelSize, previousHeight);
        this.nextContainer.resize(newNextPanelSize, nextHeight);
    }
};

dockspawn.SplitterBar.prototype._startDragging = function(e)
{
    disableGlobalTextSelection();
    if (this.mouseMovedHandler)
    {
        this.mouseMovedHandler.cancel();
        delete this.mouseMovedHandler;
    }
    if (this.mouseUpHandler)
    {
        this.mouseUpHandler.cancel();
        delete this.mouseUpHandler;
    }
    this.mouseMovedHandler = new dockspawn.EventHandler(window, 'mousemove', this.onMouseMoved.bind(this));
    this.mouseUpHandler = new dockspawn.EventHandler(window, 'mouseup', this.onMouseUp.bind(this));
    this.previousMouseEvent = e;
};

dockspawn.SplitterBar.prototype._stopDragging = function(e)
{
    enableGlobalTextSelection();
    document.body.classList.remove("disable-selection");
    if (this.mouseMovedHandler)
    {
        this.mouseMovedHandler.cancel();
        delete this.mouseMovedHandler;
    }
    if (this.mouseUpHandler)
    {
        this.mouseUpHandler.cancel();
        delete this.mouseUpHandler;
    }
};
/**
 * Deserializes the dock layout hierarchy from JSON and creates a dock hierarhcy graph
 */
dockspawn.DockGraphDeserializer = function(dockManager)
{
    this.dockManager = dockManager;
};

dockspawn.DockGraphDeserializer.prototype.deserialize = function(json)
{
    var graphInfo = JSON.parse(_json);
    var model = new dockspawn.DockModel();
    model.rootNode = this._buildGraph(graphInfo);
    return model;
};

dockspawn.DockGraphDeserializer.prototype._buildGraph = function(nodeInfo)
{
    var childrenInfo = nodeInfo.children;
    var children = [];
    var self = this;
    childrenInfo.forEach(function(childInfo)
    {
        var childNode = self._buildGraph(childInfo);
        children.push(childNode);
    });

    // Build the container owned by this node
    var container = this._createContainer(nodeInfo, children);

    // Build the node for this container and attach it's children
    var node = new dockspawn.DockNode(container);
    node.children = children;
    node.children.forEach(function(childNode) { childNode.parent = node; });

    return node;
};

dockspawn.DockGraphDeserializer.prototype._createContainer = function(nodeInfo, children)
{
    var containerType = nodeInfo.containerType;
    var containerState = nodeInfo.state;
    var container;

    var childContainers = [];
    children.forEach(function(childNode) { childContainers.push(childNode.container); });
    childContainers = [];

    if (containerType == "panel")
        container = new dockspawn.PanelContainer.loadFromState(containerState, this.dockManager);
    else if (containerType == "horizontal")
        container = new dockspawn.HorizontalDockContainer(this.dockManager, childContainers);
    else if (containerType == "vertical")
        container = new dockspawn.VerticalDockContainer(this.dockManager, childContainers);
    else if (containerType == "fill")
    {
        // Check if this is a document manager

        // TODO: Layout engine compares the string "fill", so cannot create another subclass type
        // called document_manager and have to resort to this hack. use RTTI in layout engine
        var typeDocumentManager = containerState.documentManager;
        if (typeDocumentManager)
            container = new DocumentManagerContainer(this.dockManager);
        else
            container = new dockspawn.FillDockContainer(this.dockManager);
    }
    else
        throw new dockspawn.Exception("Cannot create dock container of unknown type: " + containerType);

    // Restore the state of the container
    container.loadState(containerState);
    container.performLayout(childContainers);
    return container;
};
/**
 * The serializer saves / loads the state of the dock layout hierarchy
 */
dockspawn.DockGraphSerializer = function()
{
};

dockspawn.DockGraphSerializer.prototype.serialize = function(model)
{
    var graphInfo = this._buildGraphInfo(model.rootNode);
    return JSON.stringify(graphInfo);
};

dockspawn.DockGraphSerializer.prototype._buildGraphInfo = function(node)
{
    var nodeState = {};
    node.container.saveState(nodeState);

    var childrenInfo = [];
    var self = this;
    node.childNodes.forEach(function(childNode) {
        childrenInfo.push(self._buildGraphInfo(childNode));
    });

    var nodeInfo = {};
    nodeInfo.containerType = node.container.containerType;
    nodeInfo.state = nodeState;
    nodeInfo.children = childrenInfo;
    return nodeInfo;
};
function getPixels(pixels)
{
    if (pixels == null)
        return 0;
    return parseInt(pixels.replace("px", ""));
}

function disableGlobalTextSelection()
{
    document.body.classList.add("disable-selection");
}

function enableGlobalTextSelection()
{
    document.body.classList.remove("disable-selection");
}

function isPointInsideNode(px, py, node)
{
    var element = node.container.containerElement;
    var x = element.offsetLeft;
    var y = element.offsetTop;
    var width = element.clientWidth;
    var height = element.clientHeight;

    return (px >= x && px <= x + width && py >= y && py <= y + height);
}

function Rectangle()
{
//    num x;
//    num y;
//    num width;
//    num height;
}

function getNextId(prefix)
{
    return prefix + getNextId.counter++;
}
getNextId.counter = 0;

function removeNode(node)
{
    if (node.parentNode == null)
        return false;
    node.parentNode.removeChild(node);
    return true;
}

function Point(x, y)
{
    this.x = x;
    this.y = y;
}
dockspawn.EventHandler = function(source, eventName, target)
{
    // wrap the target
    this.target = target;
    this.eventName = eventName;
    this.source = source;

    this.source.addEventListener(eventName, this.target);
};

dockspawn.EventHandler.prototype.cancel = function()
{
    this.source.removeEventListener(this.eventName, this.target)
};
/**
 * Listens for events on the [element] and notifies the [listener]
 * if an undock event has been invoked.  An undock event is invoked
 * when the user clicks on the event and drags is beyond the
 * specified [thresholdPixels]
 */
dockspawn.UndockInitiator = function(element, listener, thresholdPixels)
{
    if (!thresholdPixels)
        thresholdPixels = 10;

    this.element = element;
    this.listener = listener;
    this.thresholdPixels = thresholdPixels;
    this._enabled = false;
};

Object.defineProperty(dockspawn.UndockInitiator.prototype, "enabled", {
    get: function() { return this._enabled; },
    set: function(value)
    {
        this._enabled = value;
        if (this._enabled)
        {
            if (this.mouseDownHandler)
            {
                this.mouseDownHandler.cancel();
                delete this.mouseDownHandler;
            }
            this.mouseDownHandler = new dockspawn.EventHandler(this.element, 'mousedown', this.onMouseDown.bind(this));
        }
        else
        {
            if (this.mouseDownHandler)
            {
                this.mouseDownHandler.cancel();
                delete this.mouseDownHandler;
            }
            if (this.mouseUpHandler)
            {
                this.mouseUpHandler.cancel();
                delete this.mouseUpHandler;
            }
            if (this.mouseMoveHandler)
            {
                this.mouseMoveHandler.cancel();
                delete this.mouseMoveHandler;
            }
        }
    }
});

dockspawn.UndockInitiator.prototype.onMouseDown = function(e)
{
    // Make sure we dont do this on floating dialogs
    if (this.enabled)
    {
        if (this.mouseUpHandler)
        {
            this.mouseUpHandler.cancel();
            delete this.mouseUpHandler;
        }
        if (this.mouseMoveHandler)
        {
            this.mouseMoveHandler.cancel();
            delete this.mouseMoveHandler;
        }
        this.mouseUpHandler = new dockspawn.EventHandler(window, 'mouseup', this.onMouseUp.bind(this));
        this.mouseMoveHandler = new dockspawn.EventHandler(window, 'mousemove', this.onMouseMove.bind(this));
        this.dragStartPosition = new Point(e.pageX, e.pageY);
    }
};

dockspawn.UndockInitiator.prototype.onMouseUp = function(e)
{
    if (this.mouseUpHandler)
    {
        this.mouseUpHandler.cancel();
        delete this.mouseUpHandler;
    }
    if (this.mouseMoveHandler)
    {
        this.mouseMoveHandler.cancel();
        delete this.mouseMoveHandler;
    }
};

dockspawn.UndockInitiator.prototype.onMouseMove = function(e)
{
    var position = new Point(e.pageX, e.pageY);
    var dx = position.x - this.dragStartPosition.x;
    var dy = position.y - this.dragStartPosition.y;
    var distance = Math.sqrt(dx * dx + dy * dy);

    if (distance > this.thresholdPixels)
    {
        this.enabled = false;
        this._requestUndock(e);
    }
};

dockspawn.UndockInitiator.prototype._requestUndock = function(e)
{
    var dragOffsetX = this.dragStartPosition.x - this.element.offsetLeft;
    var dragOffsetY = this.dragStartPosition.y - this.element.offsetTop;
    var dragOffset = new Point(dragOffsetX, dragOffsetY);
    this.listener(e, dragOffset);
};

})();
