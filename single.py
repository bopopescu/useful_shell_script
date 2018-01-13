# -*- coding: utf-8 -*-

class SingleModel(object):
    '''
    使用单例模式的时候要注意，如果导入的路径不同，会产生不同的实例，比如：
    有文件 test.py 类 MySingle 继承自SingleModel
    文件 t1.py 导入 使用 from src.test import MySingle
    文件t2.py 导入使用 frome test import MySingle  
    这要 t1 中的MySingle.instance() 和 t2 的 MySingle.instance() 将得到不同的实例  
    '''
    def __init__(self):
        '''
        Constructor
        '''
    @classmethod
    def instance(cls):
        '''
         single instance
        '''
        if hasattr(cls, "_instance"):
            return cls._instance
        cls._lock.acquire()
        if not hasattr(cls, "_instance"):
            cls._instance = cls()
        cls._lock.release()
        return cls._instance