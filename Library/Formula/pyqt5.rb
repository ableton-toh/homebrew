require 'formula'

class Pyqt5 < Formula
  homepage 'http://www.riverbankcomputing.co.uk/software/pyqt/download5'
  url 'http://downloads.sf.net/project/pyqt/PyQt5/PyQt-5.1.1/PyQt-gpl-5.1.1.tar.gz'
  sha1 '90a3d6a805da7559ad83704866c1751d698f1873'

  option 'enable-debug', "Build with debug symbols"
  option 'use-qtdir', "Use QT from $QTDIR instead of brewing qt5"

  depends_on :python3 => :recommended
  depends_on :python2 => :optional

  depends_on 'qt5' unless build.include? "use-qtdir"

  if build.with? 'python3'
    depends_on 'sip' => [:build, 'with-python3']
  else
    depends_on 'sip' => :build
  end

  if build.include? "use-qtdir" and not system ("#{ENV['QTDIR']}/bin/qmake -v")
    onoe "No suitable qmake found at #{ENV['QTDIR']}/bin/qmake."
  end

  def patches
    [
      # Enable qml-debugging
      "https://gist.github.com/ableton-toh/7660057/raw",
      # Fix bug that prevents passing keyword arguments from python.
      # Reported to upstream via email.
      "https://gist.github.com/ableton-toh/7660245/raw"
    ]
  end

  def install
    python do
      args = [ "--confirm-license",
               "--bindir=#{bin}",
               "--destdir=#{lib}/#{python.xy}/site-packages",
               # To avoid conflicst with PyQt (for Qt4):
               "--sipdir=#{share}/sip#{python.if3then3}/Qt5/",
               # sip.h could not be found automatically
               "--sip-incdir=#{Formula.factory('sip').opt_prefix}/include" ]
      args << '--debug' if build.include? 'enable-debug'
      args << "--qmake=#{ENV['QTDIR']}/bin/qmake" if build.include? 'use-qtdir'

      system python, "./configure.py", *args
      system "make"
      system "make", "install"
      system "make", "clean"  # because this python block may be run twice

      # For PyQt5 we default to put 3.x bindings in bin, unless --without-python3
      if build.with? 'python3' and build.with? 'python'
        ['pyuic5', 'pyrcc5', 'pylupdate5'].each { |f| mv(bin/f, bin/"#{f}-py2")}
      end
    end
  end

  def caveats
    python.standard_caveats if python
  end

  test do
    # To test Python 2.x, you have to `brew test pyqt --with-python`
    (testpath/'test.py').write <<-EOS.undent
      import sys
      from PyQt5 import QtGui, QtCore, QtWidgets

      class Test(QtWidgets.QWidget):
          def __init__(self, parent=None):
              QtWidgets.QWidget.__init__(self, parent)
              self.setGeometry(300, 300, 400, 150)
              self.setWindowTitle('Homebrew')
              QtWidgets.QLabel("Python " + "{0}.{1}.{2}".format(*sys.version_info[0:3]) +
                               " working with PyQt5. Quitting now...", self).move(50, 50)
              QtCore.QTimer.singleShot(1500, QtWidgets.qApp.quit)

      app = QtWidgets.QApplication([])
      window = Test()
      window.show()
      sys.exit(app.exec_())
    EOS
    python do
      system python, "test.py"
    end
  end
end
