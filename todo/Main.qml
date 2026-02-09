import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  property var pluginApi: null

  Component.onCompleted: {
    if (pluginApi) {
      // Initialize pages
      if (!pluginApi.pluginSettings.pages) {
        pluginApi.pluginSettings.pages = [{ id: 0, name: "General" }];
        pluginApi.pluginSettings.current_page_id = 0;
      }

      // Initialize todos
      if (!pluginApi.pluginSettings.todos) {
        pluginApi.pluginSettings.todos = [];
        pluginApi.pluginSettings.count = 0;
        pluginApi.pluginSettings.completedCount = 0;
      }

      // Initialize settings
      if (pluginApi.pluginSettings.isExpanded === undefined) pluginApi.pluginSettings.isExpanded = false;
      if (pluginApi.pluginSettings.useCustomColors === undefined) pluginApi.pluginSettings.useCustomColors = false;

      // Initialize priority colors
      if (!pluginApi.pluginSettings.priorityColors) {
        pluginApi.pluginSettings.priorityColors = {
          "high": Color.mError,
          "medium": Color.mPrimary,
          "low": Color.mOnSurfaceVariant
        };
      }

      // Migrate existing todos
      var todos = pluginApi.pluginSettings.todos;
      for (var i = 0; i < todos.length; i++) {
        if (todos[i].pageId === undefined) todos[i].pageId = 0;
        if (todos[i].priority === undefined || !["high", "medium", "low"].includes(todos[i].priority)) {
          todos[i].priority = "medium";
        }
        if (todos[i].details === undefined) todos[i].details = "";
      }

      pluginApi.saveSettings();
    }
  }

  // ============================================
  // IPC Handlers
  // ============================================

  IpcHandler {
    target: "plugin:todo"

    function togglePanel() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(screen => {
        pluginApi.togglePanel(screen);
      });
    }

    // Todo Read
    function getTodos(): string {
      if (!pluginApi) return "[]";
      return JSON.stringify(pluginApi.pluginSettings.todos || []);
    }

    function getTodo(id: string): string {
      if (!pluginApi || !id) return "";
      var todos = pluginApi.pluginSettings.todos || [];
      for (var i = 0; i < todos.length; i++) {
        if (todos[i].id == id) {
          return JSON.stringify(todos[i]);
        }
      }
      return "";
    }

    // Todo Create
    function addTodo(text: string, priority: string, pageId: int) {
      if (!pluginApi) return;

      if (!text || !text.trim()) {
        ToastService.showError(pluginApi.tr("main.error_text_empty"));
        return;
      }

      if (!["high", "medium", "low"].includes(priority)) {
        ToastService.showError(pluginApi.tr("main.error_invalid_priority"));
        return;
      }

      // If pageId is not provided, fallback to current page, then default page (0)
      var targetPageId =
        (pageId === undefined || pageId === null)
          ? (pluginApi.pluginSettings.current_page_id ?? 0)
          : pageId;
      if (targetPageId < 0 || !pageExists(targetPageId)) {
        ToastService.showError(pluginApi.tr("main.error_page_not_found"));
        return;
      }

      if (createTodo(text.trim(), priority, targetPageId)) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.added_new_todo"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_create_failed"));
      }
    }

    function addTodoDefault(text: string) {
      addTodo(text, "medium", pluginApi?.pluginSettings?.current_page_id || 0);
    }

    // Todo Update
    function setTodoPriority(id: string, priority: string) {
      if (!pluginApi || !id) return;

      if (!["high", "medium", "low"].includes(priority)) {
        ToastService.showError(pluginApi.tr("main.error_invalid_priority"));
        return;
      }

      if (updateTodo(id, { priority: priority })) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.updated_todo_priority"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_update_failed"));
      }
    }

    function setTodoCompleted(id: string, completed: bool) {
      if (!pluginApi || !id) return;

      if (updateTodo(id, { completed: completed })) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.updated_todo"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_update_failed"));
      }
    }

    function setTodoDetails(id: string, details: string) {
      if (!pluginApi || !id) return;

      if (updateTodo(id, { details: details })) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.updated_todo"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_update_failed"));
      }
    }

    function setTodoText(id: string, text: string) {
      if (!pluginApi || !id) return;

      if (!text || !text.trim()) {
        ToastService.showError(pluginApi.tr("main.error_text_empty"));
        return;
      }

      if (updateTodo(id, { text: text.trim() })) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.updated_todo"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_update_failed"));
      }
    }

    function toggleTodo(id: string) {
      if (!pluginApi || !id) return;

      var todo = findTodo(id);
      if (!todo) {
        ToastService.showError(pluginApi.tr("main.error_todo_not_found"));
        return;
      }

      if (updateTodo(id, { completed: !todo.completed })) {
        pluginApi.saveSettings();
        var action = !todo.completed
          ? pluginApi.tr("main.todo_completed")
          : pluginApi.tr("main.todo_marked_incomplete");
        ToastService.showNotice(pluginApi.tr("main.todo_status_changed") + action);
      } else {
        ToastService.showError(pluginApi.tr("main.error_update_failed"));
      }
    }

    // Todo Delete
    function removeTodo(id: string) {
      if (!pluginApi || !id) return;

      if (deleteTodo(id)) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.removed_todo"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_remove_failed"));
      }
    }

    function clearCompleted() {
      if (!pluginApi) return;

      var cleared = clearCompletedTodos();
      if (cleared >= 0) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("main.cleared_completed_todos") + cleared + pluginApi.tr("main.completed_todos_suffix"));
      } else {
        ToastService.showError(pluginApi.tr("main.error"));
      }
    }

    function clearAll() {
      if (!pluginApi) return;

      clearAllTodos();
      pluginApi.saveSettings();
      ToastService.showNotice(pluginApi.tr("main.cleared_all_todos"));
    }

    // Statistics
    function getCount(): string {
      if (!pluginApi) {
        return JSON.stringify({
          total: 0,
          active: 0,
          completed: 0
        });
      }

      var todos = pluginApi.pluginSettings.todos || [];
      var completed = countCompleted();

      return JSON.stringify({
        total: todos.length,
        active: todos.length - completed,
        completed: completed
      });
    }

    // Page
    function getPages(): string {
      if (!pluginApi) return "[]";
      return JSON.stringify(pluginApi.pluginSettings.pages || []);
    }

    function addPage(name: string) {
      if (!pluginApi) return;

      var trimmedName = name.trim();
      if (!trimmedName) {
        ToastService.showError(pluginApi.tr("settings.pages.empty_name"));
        return;
      }

      if (pageNameExists(trimmedName)) {
        ToastService.showError(pluginApi.tr("settings.pages.name_exists"));
        return;
      }

      if (createPage(trimmedName)) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("settings.pages.added_page") + trimmedName);
      } else {
        ToastService.showError(pluginApi.tr("settings.pages.error_creating"));
      }
    }

    function renamePage(pageId: int, newName: string) {
      if (!pluginApi || pageId < 0) return;

      if (!pageExists(pageId)) {
        ToastService.showError(pluginApi.tr("main.error_page_not_found"));
        return;
      }

      var trimmedName = newName.trim();
      if (!trimmedName) {
        ToastService.showError(pluginApi.tr("settings.pages.empty_name"));
        return;
      }

      if (pageNameExistsExcluding(pageId, trimmedName)) {
        ToastService.showError(pluginApi.tr("settings.pages.name_exists"));
        return;
      }

      if (renamePageInternal(pageId, trimmedName)) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("settings.pages.renamed_page"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_rename_failed"));
      }
    }

    function removePage(pageId: int) {
      if (!pluginApi || pageId < 0) return;

      if (!pageExists(pageId)) {
        ToastService.showError(pluginApi.tr("main.error_page_not_found"));
        return;
      }

      if (pageId === 0) {
        ToastService.showError(pluginApi.tr("settings.pages.cannot_delete_default"));
        return;
      }

      if (isLastPage()) {
        ToastService.showError(pluginApi.tr("settings.pages.cannot_delete_last"));
        return;
      }

      if (deletePage(pageId)) {
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi.tr("settings.pages.deleted_page"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_delete_failed"));
      }
    }
  }

  // ============================================
  // Helper Functions
  // ============================================

  function findTodo(id: string) {
    var todos = pluginApi?.pluginSettings?.todos || [];
    return todos.find(t => t.id == id) || null;
  }

  function findTodoIndex(id: string) {
    var todos = pluginApi?.pluginSettings?.todos || [];
    return todos.findIndex(t => t.id == id);
  }

  function pageExists(pageId: int) {
    var pages = pluginApi?.pluginSettings?.pages || [];
    return pages.some(p => p.id === pageId);
  }

  function pageNameExists(name: string) {
    var pages = pluginApi?.pluginSettings?.pages || [];
    return pages.some(p => p.name.toLowerCase() === name.toLowerCase());
  }

  function pageNameExistsExcluding(excludeId: int, name: string) {
    var pages = pluginApi?.pluginSettings?.pages || [];
    return pages.some(p => p.id !== excludeId && p.name.toLowerCase() === name.toLowerCase());
  }

  function isLastPage() {
    var pages = pluginApi?.pluginSettings?.pages || [];
    return pages.length <= 1;
  }

  function countCompleted() {
    var todos = pluginApi?.pluginSettings?.todos || [];
    return todos.filter(t => t.completed).length;
  }

  // ============================================
  // Internal Functions
  // ============================================

  // Todo Operations
  function createTodo(text: string, priority: string, pageId: int): bool {
    var newTodo = {
      id: Date.now(),
      text: text,
      completed: false,
      createdAt: new Date().toISOString(),
      pageId: pageId,
      priority: priority,
      details: ""
    };

    var todos = pluginApi?.pluginSettings?.todos || [];

    var insertIndex = todos.length;
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].pageId === pageId) {
        insertIndex = i;
        break;
      }
    }
    todos.splice(insertIndex, 0, newTodo);

    pluginApi.pluginSettings.todos = todos;
    pluginApi.pluginSettings.count = todos.length;

    return true;
  }

  function updateTodo(id: string, updates: object): bool {
    var todo = findTodo(id);
    if (!todo) return false;

    var oldCompleted = todo.completed;

    if (updates.text !== undefined) todo.text = updates.text;
    if (updates.completed !== undefined) todo.completed = updates.completed;
    if (updates.priority !== undefined) todo.priority = updates.priority;
    if (updates.details !== undefined) todo.details = updates.details;

    // Maintain completedCount if completed status changed
    if (updates.completed !== undefined && oldCompleted !== updates.completed) {
      pluginApi.pluginSettings.completedCount = countCompleted();
    }

    return true;
  }

  function deleteTodo(id: string): bool {
    var index = findTodoIndex(id);
    if (index === -1) return false;

    var todos = pluginApi?.pluginSettings?.todos || [];
    todos.splice(index, 1);

    pluginApi.pluginSettings.todos = todos;
    pluginApi.pluginSettings.count = todos.length;
    pluginApi.pluginSettings.completedCount = countCompleted();

    return true;
  }

  function clearCompletedTodos(): int {
    var todos = pluginApi?.pluginSettings?.todos || [];
    var active = todos.filter(t => !t.completed);
    var cleared = todos.length - active.length;

    pluginApi.pluginSettings.todos = active;
    pluginApi.pluginSettings.count = active.length;
    pluginApi.pluginSettings.completedCount = 0;

    return cleared;
  }

  function clearAllTodos() {
    pluginApi.pluginSettings.todos = [];
    pluginApi.pluginSettings.count = 0;
    pluginApi.pluginSettings.completedCount = 0;
  }

  // Page Operations
  function createPage(name: string): bool {
    var pages = pluginApi?.pluginSettings?.pages || [];
    var newId = pages.length > 0 ? Math.max(...pages.map(p => p.id)) + 1 : 0;

    pages.push({ id: newId, name: name });
    pluginApi.pluginSettings.pages = pages;

    return true;
  }

  function renamePageInternal(pageId: int, newName: string): bool {
    var pages = pluginApi?.pluginSettings?.pages || [];

    pages.forEach(p => {
      if (p.id === pageId) p.name = newName;
    });

    pluginApi.pluginSettings.pages = pages;

    return true;
  }

  function deletePage(pageId: int): bool {
    var pages = pluginApi?.pluginSettings?.pages || [];
    var todos = pluginApi?.pluginSettings?.todos || [];

    // Move todos to default page
    todos.forEach(t => {
      if (t.pageId === pageId) t.pageId = 0;
    });

    // Remove page
    var newPages = pages.filter(p => p.id !== pageId);
    newPages.forEach((p, i) => p.id = i);

    // Update current page if needed
    if (pluginApi?.pluginSettings?.current_page_id === pageId) {
      pluginApi.pluginSettings.current_page_id = 0;
    }

    pluginApi.pluginSettings.pages = newPages;
    pluginApi.pluginSettings.todos = todos;

    return true;
  }
}
