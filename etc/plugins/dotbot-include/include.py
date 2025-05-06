import os
import dotbot
from dotbot.cli import read_config
from dotbot.dispatcher import Dispatcher


class Include(dotbot.Plugin):

    '''
    Include the targeted configuration file
    '''

    _directive = 'include'

    def can_handle(self, directive):
        return directive == self._directive

    def handle(self, directive, data):
        if not self.can_handle(directive):
            raise ValueError('%s cannot handle directive %s' % (self.__name__, directive)) # noqa

        # Error handle?
        filename = data if isinstance(data, str) else data.get('path')
        tasks = read_config([filename])

        defaults = self._context.defaults().get(self._directive, {})
        isolated_default = defaults.get('isolated', False)
        isolated = data.get('isolated', isolated_default) if isinstance(
            data, dict) else isolated_default

        self._dispatcher = self._create_dispatcher(isolated)

        return self._execute_nested(self._dispatcher, tasks)

    def _create_dispatcher(self, isolated):
        dispatcher = Dispatcher(self._context.base_directory(),
                                only=self._context.options().only,
                                skip=self._context.options().skip,
                                options=self._context.options())
        if not isolated:
            # ugly hack...
            dispatcher._context = self._context
            for p in dispatcher._plugins:
                p._context = self._context
        return dispatcher

    def _execute_nested(self, dispatcher, data):
        # if the data is a dictionary, wrap it in a list
        data = data if type(data) is list else [data]
        return dispatcher.dispatch(data)
